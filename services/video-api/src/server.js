const express = require("express");
const app = express();
const PORT = process.env.PORT || 80;

app.get("/", (req, res) => {
    res.json({
        service: "video-api",
        status: "running",
        environment: process.env.NODE_ENV || "dev"
    });
});

app.get("/health", (req, res) => {
    res.status(200).json({
        status: "healthy"
    });
});

app.listen(PORT, () => {

  console.log(`Video API running on port ${PORT}`);

});