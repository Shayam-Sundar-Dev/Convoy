const express = require("express");
const { z } = require("zod");
const { prisma } = require("../config/db");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();
router.use(requireAuth);

const DEFAULT_CATEGORIES = [
  { id: "default_fuel", name: "Fuel", icon: "fuel" },
  { id: "default_food", name: "Food & Drinks", icon: "food" },
  { id: "default_tolls", name: "Tolls", icon: "tolls" },
  { id: "default_lodging", name: "Lodging", icon: "lodging" },
  { id: "default_parking", name: "Parking", icon: "parking" },
  { id: "default_other", name: "Other", icon: "other" },
];

/** GET /expenses — list expenses, people, and categories for a convoy or personal dashboard */
router.get("/", async (req, res) => {
  try {
    const code = req.query.code ? req.query.code.toUpperCase() : null;
    let convoy = null;

    if (code) {
      convoy = await prisma.convoy.findUnique({
        where: { code },
        include: { members: { include: { user: { select: { id: true, name: true } } } } },
      });
    }

    const whereClause = convoy ? { convoyId: convoy.id } : { userId: req.userId };

    const [expenses, customCategories, customPeople] = await Promise.all([
      prisma.expense.findMany({
        where: { ...whereClause, sessionId: null },
        orderBy: { createdAt: "desc" },
      }),
      prisma.expenseCategory.findMany({
        where: convoy ? { convoyId: convoy.id } : { userId: req.userId },
        orderBy: { createdAt: "asc" },
      }),
      prisma.person.findMany({
        where: convoy ? { convoyId: convoy.id } : { userId: req.userId },
        orderBy: { createdAt: "asc" },
      }),
    ]);

    // Combine default and custom categories
    const categories = [...DEFAULT_CATEGORIES, ...customCategories];

    // Return active custom people registered for this trip
    const people = customPeople;

    res.json({
      expenses,
      people,
      categories,
    });
  } catch (err) {
    console.error("GET /expenses error:", err);
    res.status(500).json({ error: "Failed to fetch expenses", details: err.message });
  }
});

/** POST /expenses — create an expense */
const createExpenseSchema = z.object({
  title: z.string().min(1).max(100),
  amount: z.number().positive(),
  categoryName: z.string().min(1),
  categoryId: z.string().optional(),
  paidByName: z.string().min(1),
  personId: z.string().optional(),
  convoyCode: z.string().optional(),
});

router.post("/", async (req, res) => {
  try {
    const parsed = createExpenseSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    const d = parsed.data;

    let convoy = null;
    if (d.convoyCode) {
      convoy = await prisma.convoy.findUnique({ where: { code: d.convoyCode.toUpperCase() } });
    }

    // Ensure person exists in the list for future reference
    const personName = d.paidByName.trim();
    let person = await prisma.person.findFirst({
      where: {
        name: { equals: personName, mode: "insensitive" },
        ...(convoy ? { convoyId: convoy.id } : { userId: req.userId }),
      },
    });

    if (!person) {
      person = await prisma.person.create({
        data: {
          name: personName,
          convoyId: convoy ? convoy.id : null,
          userId: req.userId,
        },
      });
    }

    // Verify category exists or nullify categoryId if it is a virtual default or not found
    let validCategoryId = null;
    if (d.categoryId && !d.categoryId.startsWith("default_")) {
      const existingCat = await prisma.expenseCategory.findUnique({ where: { id: d.categoryId } });
      if (existingCat) {
        validCategoryId = existingCat.id;
      }
    }

    const expense = await prisma.expense.create({
      data: {
        title: d.title,
        amount: d.amount,
        categoryName: d.categoryName,
        categoryId: validCategoryId,
        paidByName: personName,
        personId: person.id,
        userId: req.userId,
        convoyId: convoy ? convoy.id : null,
      },
    });

    if (convoy) {
      const io = req.app.get("io");
      if (io) {
        io.to(`convoy:${convoy.code}`).emit("expense:new", { expense, person });
      }
    }

    res.status(201).json(expense);
  } catch (err) {
    console.error("POST /expenses error:", err);
    res.status(500).json({ error: "Failed to create expense", details: err.message });
  }
});

/** DELETE /expenses/:id — delete an expense */
router.delete("/:id", async (req, res) => {
  try {
    const expense = await prisma.expense.findUnique({ where: { id: req.params.id } });
    if (!expense) return res.status(404).json({ error: "Expense not found" });

    await prisma.expense.delete({ where: { id: req.params.id } });

    if (expense.convoyId) {
      const convoy = await prisma.convoy.findUnique({ where: { id: expense.convoyId } });
      if (convoy) {
        const io = req.app.get("io");
        if (io) {
          io.to(`convoy:${convoy.code}`).emit("expense:deleted", { id: expense.id });
        }
      }
    }

    res.json({ ok: true });
  } catch (err) {
    console.error("DELETE /expenses/:id error:", err);
    res.status(500).json({ error: "Failed to delete expense", details: err.message });
  }
});

/** POST /expenses/people — add a person */
const createPersonSchema = z.object({
  name: z.string().min(1).max(80),
  convoyCode: z.string().optional(),
});

router.post("/people", async (req, res) => {
  try {
    const parsed = createPersonSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    const d = parsed.data;

    let convoy = null;
    if (d.convoyCode) {
      convoy = await prisma.convoy.findUnique({ where: { code: d.convoyCode.toUpperCase() } });
    }

    const person = await prisma.person.create({
      data: {
        name: d.name.trim(),
        convoyId: convoy ? convoy.id : null,
        userId: req.userId,
      },
    });

    if (convoy) {
      const io = req.app.get("io");
      if (io) {
        io.to(`convoy:${convoy.code}`).emit("person:new", person);
      }
    }

    res.status(201).json(person);
  } catch (err) {
    console.error("POST /expenses/people error:", err);
    res.status(500).json({ error: "Failed to add person", details: err.message });
  }
});

/** DELETE /expenses/people/:id — remove a person from active tracking */
router.delete("/people/:id", async (req, res) => {
  try {
    const person = await prisma.person.findUnique({ where: { id: req.params.id } });
    if (!person) return res.status(404).json({ error: "Person not found" });

    // Nullify references in any expenses
    await prisma.expense.updateMany({
      where: { personId: req.params.id },
      data: { personId: null },
    });

    await prisma.person.delete({ where: { id: req.params.id } });

    if (person.convoyId) {
      const convoy = await prisma.convoy.findUnique({ where: { id: person.convoyId } });
      if (convoy) {
        const io = req.app.get("io");
        if (io) {
          io.to(`convoy:${convoy.code}`).emit("person:deleted", { id: person.id });
        }
      }
    }

    res.json({ ok: true });
  } catch (err) {
    console.error("DELETE /expenses/people/:id error:", err);
    res.status(500).json({ error: "Failed to delete person", details: err.message });
  }
});

/** POST /expenses/categories — add a custom category */
const createCategorySchema = z.object({
  name: z.string().min(1).max(60),
  icon: z.string().default("category"),
  convoyCode: z.string().optional(),
});

router.post("/categories", async (req, res) => {
  try {
    const parsed = createCategorySchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    const d = parsed.data;

    let convoy = null;
    if (d.convoyCode) {
      convoy = await prisma.convoy.findUnique({ where: { code: d.convoyCode.toUpperCase() } });
    }

    const category = await prisma.expenseCategory.create({
      data: {
        name: d.name.trim(),
        icon: d.icon,
        convoyId: convoy ? convoy.id : null,
        userId: req.userId,
      },
    });

    if (convoy) {
      const io = req.app.get("io");
      if (io) {
        io.to(`convoy:${convoy.code}`).emit("category:new", category);
      }
    }

    res.status(201).json(category);
  } catch (err) {
    console.error("POST /expenses/categories error:", err);
    res.status(500).json({ error: "Failed to add category", details: err.message });
  }
});

/** PATCH /expenses/categories/:id — edit a category */
const editCategorySchema = z.object({
  name: z.string().min(1).max(60),
  icon: z.string().optional(),
});

router.patch("/categories/:id", async (req, res) => {
  try {
    const parsed = editCategorySchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    const d = parsed.data;

    const category = await prisma.expenseCategory.update({
      where: { id: req.params.id },
      data: {
        name: d.name.trim(),
        ...(d.icon ? { icon: d.icon } : {}),
      },
    });

    // Update cached categoryName on any matching expenses
    await prisma.expense.updateMany({
      where: { categoryId: category.id },
      data: { categoryName: category.name },
    });

    if (category.convoyId) {
      const convoy = await prisma.convoy.findUnique({ where: { id: category.convoyId } });
      if (convoy) {
        const io = req.app.get("io");
        if (io) {
          io.to(`convoy:${convoy.code}`).emit("category:updated", category);
        }
      }
    }

    res.json(category);
  } catch (err) {
    console.error("PATCH /expenses/categories/:id error:", err);
    res.status(500).json({ error: "Failed to update category", details: err.message });
  }
});

/** DELETE /expenses/categories/:id — delete a custom category */
router.delete("/categories/:id", async (req, res) => {
  try {
    const category = await prisma.expenseCategory.findUnique({ where: { id: req.params.id } });
    if (!category) return res.status(404).json({ error: "Category not found" });

    // Nullify foreign key on expenses first
    await prisma.expense.updateMany({
      where: { categoryId: req.params.id },
      data: { categoryId: null },
    });

    await prisma.expenseCategory.delete({ where: { id: req.params.id } });

    if (category.convoyId) {
      const convoy = await prisma.convoy.findUnique({ where: { id: category.convoyId } });
      if (convoy) {
        const io = req.app.get("io");
        if (io) {
          io.to(`convoy:${convoy.code}`).emit("category:deleted", { id: category.id });
        }
      }
    }

    res.json({ ok: true });
  } catch (err) {
    console.error("DELETE /expenses/categories/:id error:", err);
    res.status(500).json({ error: "Failed to delete category", details: err.message });
  }
});

/** POST /expenses/complete-session — archive current active expenses into a named history session and reset tracking */
const completeSessionSchema = z.object({
  name: z.string().min(1).max(100),
  convoyCode: z.string().optional(),
});

router.post("/complete-session", async (req, res) => {
  try {
    const parsed = completeSessionSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.flatten() });
    const d = parsed.data;

    let convoy = null;
    if (d.convoyCode) {
      convoy = await prisma.convoy.findUnique({
        where: { code: d.convoyCode.toUpperCase() },
        include: { members: true },
      });
    }

    const whereClause = convoy ? { convoyId: convoy.id } : { userId: req.userId };

    // Fetch all active expenses
    const activeExpenses = await prisma.expense.findMany({
      where: { ...whereClause, sessionId: null },
      orderBy: { createdAt: "desc" },
    });

    if (activeExpenses.length === 0) {
      return res.status(400).json({ error: "No active expenses to complete." });
    }

    // Fetch active travelers / people before resetting
    const activePeople = await prisma.person.findMany({
      where: whereClause,
    });

    const currentUser = await prisma.user.findUnique({
      where: { id: req.userId },
      select: { id: true, name: true },
    });

    // Collect all participant names (current user + convoy members + active people + expense payers)
    const personNames = new Set();
    if (currentUser && currentUser.name && currentUser.name.trim()) {
      personNames.add(currentUser.name.trim());
    }
    if (convoy && convoy.members) {
      for (const m of convoy.members) {
        if (m.user && m.user.name && m.user.name.trim()) {
          personNames.add(m.user.name.trim());
        }
      }
    }
    for (const p of activePeople) {
      if (p.name && p.name.trim()) personNames.add(p.name.trim());
    }
    for (const e of activeExpenses) {
      if (e.paidByName && e.paidByName.trim()) personNames.add(e.paidByName.trim());
    }

    // Calculate totals
    const totalAmount = activeExpenses.reduce((sum, e) => sum + e.amount, 0);
    const peopleCount = Math.max(personNames.size, 1);
    const splitAmount = totalAmount / peopleCount;

    // Calculate detailed breakdown for each participant
    const participants = Array.from(personNames).map((name) => {
      const paid = activeExpenses
        .filter((e) => e.paidByName.trim().toLowerCase() === name.toLowerCase())
        .reduce((sum, e) => sum + e.amount, 0);
      return {
        name,
        paid: Math.round(paid * 100) / 100,
        balance: Math.round((paid - splitAmount) * 100) / 100,
      };
    });

    // Create history session
    const session = await prisma.expenseSession.create({
      data: {
        name: d.name.trim(),
        totalAmount,
        peopleCount,
        splitAmount,
        participants: JSON.stringify(participants),
        convoyId: convoy ? convoy.id : null,
        userId: req.userId,
      },
    });

    // Move active expenses to this session
    await prisma.expense.updateMany({
      where: { ...whereClause, sessionId: null },
      data: { sessionId: session.id },
    });

    // RESET active travelers so the next trip starts completely fresh!
    await prisma.person.deleteMany({
      where: whereClause,
    });

    // Include the archived expenses in the returned session
    const fullSession = await prisma.expenseSession.findUnique({
      where: { id: session.id },
      include: {
        expenses: {
          orderBy: { createdAt: "desc" },
        },
      },
    });

    const sessionWithParticipants = {
      ...fullSession,
      participants,
    };

    if (convoy) {
      const io = req.app.get("io");
      if (io) {
        io.to(`convoy:${convoy.code}`).emit("expense:session_completed", sessionWithParticipants);
      }
    }

    res.status(201).json(sessionWithParticipants);
  } catch (err) {
    console.error("POST /expenses/complete-session error:", err);
    res.status(500).json({ error: "Failed to complete expense session", details: err.message });
  }
});

/** GET /expenses/history — list completed past expense sessions with full breakdown */
router.get("/history", async (req, res) => {
  try {
    const code = req.query.code ? req.query.code.toUpperCase() : null;
    let convoy = null;

    if (code) {
      convoy = await prisma.convoy.findUnique({
        where: { code },
        include: { members: { include: { user: { select: { id: true, name: true } } } } },
      });
    }

    const whereClause = convoy ? { convoyId: convoy.id } : { userId: req.userId };

    const [currentUser, sessions] = await Promise.all([
      req.userId
        ? prisma.user.findUnique({
            where: { id: req.userId },
            select: { id: true, name: true },
          })
        : null,
      prisma.expenseSession.findMany({
        where: whereClause,
        include: {
          user: { select: { id: true, name: true } },
          convoy: {
            include: {
              members: { include: { user: { select: { id: true, name: true } } } },
            },
          },
          expenses: {
            orderBy: { createdAt: "desc" },
          },
        },
        orderBy: { completedAt: "desc" },
      }),
    ]);

    // Attach participants breakdown to each past session
    const sessionsWithParticipants = sessions.map((s) => {
      let participants = [];
      if (s.participants) {
        try {
          participants = JSON.parse(s.participants);
        } catch (_) {}
      }

      if (!Array.isArray(participants) || participants.length === 0) {
        const personNames = new Set();

        // 1. Session owner / creator
        if (s.user && s.user.name && s.user.name.trim()) {
          personNames.add(s.user.name.trim());
        }
        // 2. Currently logged-in user if this is their trip or convoy
        if (currentUser && currentUser.name && currentUser.name.trim()) {
          personNames.add(currentUser.name.trim());
        }
        // 3. Convoy members
        if (s.convoy && s.convoy.members) {
          for (const m of s.convoy.members) {
            if (m.user && m.user.name && m.user.name.trim()) {
              personNames.add(m.user.name.trim());
            }
          }
        }
        // 4. Payers on expenses
        for (const exp of s.expenses) {
          if (exp.paidByName && exp.paidByName.trim()) {
            personNames.add(exp.paidByName.trim());
          }
        }

        // Fill up to s.peopleCount with numbered traveler placeholders if names were lost
        let travelerIdx = 2;
        while (personNames.size < (s.peopleCount || 1)) {
          personNames.add(`Traveler ${travelerIdx}`);
          travelerIdx++;
        }

        // Map amounts spent by person (case-insensitive)
        const spentByPerson = {};
        for (const exp of s.expenses) {
          const name = (exp.paidByName || "Unknown").trim().toLowerCase();
          spentByPerson[name] = (spentByPerson[name] || 0) + exp.amount;
        }

        const totalSpent = s.totalAmount > 0
          ? s.totalAmount
          : s.expenses.reduce((sum, e) => sum + e.amount, 0);

        const count = Math.max(personNames.size, s.peopleCount || 1);
        const split = s.splitAmount > 0 ? s.splitAmount : (totalSpent / count);

        participants = Array.from(personNames).map((name) => {
          const paid = spentByPerson[name.toLowerCase()] || 0.0;
          return {
            name,
            paid: Math.round(paid * 100) / 100,
            balance: Math.round((paid - split) * 100) / 100,
          };
        });
      }

      return {
        ...s,
        participants,
      };
    });

    res.json({ sessions: sessionsWithParticipants });
  } catch (err) {
    console.error("GET /expenses/history error:", err);
    res.status(500).json({ error: "Failed to fetch expense history", details: err.message });
  }
});

/** DELETE /expenses/history/:id — delete a past expense history session */
router.delete("/history/:id", async (req, res) => {
  try {
    const session = await prisma.expenseSession.findUnique({ where: { id: req.params.id } });
    if (!session) return res.status(404).json({ error: "Session not found" });

    await prisma.expenseSession.delete({ where: { id: req.params.id } });

    if (session.convoyId) {
      const convoy = await prisma.convoy.findUnique({ where: { id: session.convoyId } });
      if (convoy) {
        const io = req.app.get("io");
        if (io) {
          io.to(`convoy:${convoy.code}`).emit("expense:session_deleted", { id: session.id });
        }
      }
    }

    res.json({ ok: true });
  } catch (err) {
    console.error("DELETE /expenses/history/:id error:", err);
    res.status(500).json({ error: "Failed to delete expense session", details: err.message });
  }
});

module.exports = router;

