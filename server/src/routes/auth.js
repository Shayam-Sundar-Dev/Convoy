const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const axios = require("axios");
const { z } = require("zod");
const { prisma } = require("../config/db");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

const registerSchema = z.object({
  name: z.string().min(1).max(80),
  email: z.string().email(),
  password: z.string().min(8),
});

router.post("/register", async (req, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const { name, email, password } = parsed.data;
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) return res.status(409).json({ error: "An account with that email already exists" });

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({ data: { name, email, passwordHash } });

  const token = signToken(user.id);
  res.status(201).json({ token, user: publicUser(user) });
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

router.post("/login", async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const { email, password } = parsed.data;
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) return res.status(401).json({ error: "Incorrect email or password" });

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return res.status(401).json({ error: "Incorrect email or password" });

  const token = signToken(user.id);
  res.json({ token, user: publicUser(user) });
});

/** POST /auth/google — sign in or sign up with Google */
const googleAuthSchema = z.object({
  idToken: z.string().optional(),
  email: z.string().email(),
  name: z.string().optional(),
  providerId: z.string().optional(),
});

router.post("/google", async (req, res) => {
  const parsed = googleAuthSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  let { email, name, providerId, idToken } = parsed.data;

  if (idToken) {
    try {
      const googleRes = await axios.get(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
      if (googleRes.data && googleRes.data.email) {
        email = googleRes.data.email;
        name = googleRes.data.name || name;
        providerId = googleRes.data.sub || providerId;
      }
    } catch (err) {
      console.warn("Google token verification warning, using payload:", err.message);
    }
  }

  let user = await prisma.user.findFirst({
    where: {
      OR: [
        { email },
        ...(providerId ? [{ providerId }] : []),
      ],
    },
  });

  if (!user) {
    user = await prisma.user.create({
      data: {
        name: name || email.split("@")[0],
        email,
        provider: "google",
        providerId,
      },
    });
  } else if (!user.provider) {
    user = await prisma.user.update({
      where: { id: user.id },
      data: { provider: "google", providerId: providerId || user.providerId },
    });
  }

  const token = signToken(user.id);
  res.json({ token, user: publicUser(user) });
});

/** POST /auth/apple — sign in or sign up with Apple */
const appleAuthSchema = z.object({
  identityToken: z.string().optional(),
  email: z.string().email(),
  name: z.string().optional(),
  providerId: z.string().optional(),
});

router.post("/apple", async (req, res) => {
  const parsed = appleAuthSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  let { email, name, providerId, identityToken } = parsed.data;

  if (identityToken) {
    try {
      const decoded = jwt.decode(identityToken);
      if (decoded && decoded.email) email = decoded.email;
      if (decoded && decoded.sub) providerId = decoded.sub;
    } catch (err) {
      console.warn("Apple token decode warning:", err.message);
    }
  }

  let user = await prisma.user.findFirst({
    where: {
      OR: [
        { email },
        ...(providerId ? [{ providerId }] : []),
      ],
    },
  });

  if (!user) {
    user = await prisma.user.create({
      data: {
        name: name || email.split("@")[0] || "Apple User",
        email,
        provider: "apple",
        providerId,
      },
    });
  } else if (!user.provider) {
    user = await prisma.user.update({
      where: { id: user.id },
      data: { provider: "apple", providerId: providerId || user.providerId },
    });
  }

  const token = signToken(user.id);
  res.json({ token, user: publicUser(user) });
});

function signToken(userId) {
  return jwt.sign({ sub: userId }, process.env.JWT_SECRET, { expiresIn: "30d" });
}

function publicUser(user) {
  return { id: user.id, name: user.name, email: user.email };
}

/** PATCH /auth/me — update the current user's profile. */
const updateMeSchema = z.object({
  name: z.string().min(1).max(80).optional(),
});

router.patch("/me", requireAuth, async (req, res) => {
  if (!req.userId) return res.status(401).json({ error: "Not authenticated" });
  const parsed = updateMeSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });

  const user = await prisma.user.update({
    where: { id: req.userId },
    data: { ...parsed.data },
  });
  res.json(publicUser(user));
});

module.exports = router;

