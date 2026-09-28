require("dotenv").config();
const http = require("http");
const express = require("express");
const cors = require("cors");
const { Server } = require("socket.io");

const authRoutes = require("./routes/auth");
const convoyRoutes = require("./routes/convoy");
const expenseRoutes = require("./routes/expense");
const { attachSockets } = require("./sockets");

const app = express();
app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => res.json({ ok: true }));
app.use("/auth", authRoutes);
app.use("/convoys", convoyRoutes);
app.use("/expenses", expenseRoutes);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "Something went wrong" });
});

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });
app.set("io", io);
attachSockets(io);

const PORT = process.env.PORT || 4000;
server.listen(PORT, () => {
  console.log(`Convoy server listening on :${PORT}`);
});

