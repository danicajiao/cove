# Cove Scripts

This directory contains Node.js scripts for Cove project maintenance, including Firestore migrations.

## Setup

1. **Download your Firebase service account key:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save as `serviceAccountKey.json` in this `scripts/` directory

2. **Install dependencies:**
   ```bash
   cd scripts
   npm install
   ```

## Available Migrations

### Migrate ID Fields

Renames identifier fields from `*ID` to `*Id` to follow Swift naming conventions.

**Changes:**
- `categoryID` → `categoryId`
- `productDetailsID` → `productDetailsId`
- `productID` → `productId`

**Collections affected:**
- `products`
- `brands`
- `users/{uid}/favorites`

**Run:**
```bash
npm run migrate:id-fields
```

## Security Notes

⚠️ **NEVER commit `serviceAccountKey.json` to git!**

This file is automatically ignored by `.gitignore`. It contains credentials that give full access to your Firebase project.

## Adding New Migrations

1. Create a new file in `migrations/` directory
2. Follow the existing pattern
3. Add a script command to `package.json`
4. Document it in this README
