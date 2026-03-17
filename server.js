const express = require('express');
const app = express();
const port = 3000;

// ה-Endpoint שהתרגיל דורש לבדיקות בריאות
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// סתם דף הבית שיהיה לנו משהו לראות
app.get('/', (req, res) => {
  res.send('Hello from my CI/CD Pipeline!');
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});