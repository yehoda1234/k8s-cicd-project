# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Stage 2: Production
FROM node:18-alpine
WORKDIR /app

# העתקה של הספריות והקוד מהשלב הקודם (ה-builder)
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./
COPY --from=builder /app/package.json ./

# הגדרת משתמש שאינו root - פרקטיקת אבטחה שנדרשת בהערכת התרגיל
USER node

EXPOSE 3000
CMD ["npm", "start"]