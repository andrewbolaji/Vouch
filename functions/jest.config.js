module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testTimeout: 30000,
  // index.test.ts and submit_comment.test.ts both hit the same
  // physical Firestore/Auth emulator, and index.test.ts's
  // clearFirestore() wipes entire top-level collections rather than
  // only its own fixtures. Running test files in parallel workers
  // (Jest's default) lets one file's clear silently wipe data the
  // other file just wrote, mid-test. Forcing a single worker makes
  // every emulator-backed test file run sequentially instead.
  maxWorkers: 1,
  roots: ["<rootDir>/src"],
  transform: {
    "^.+\\.tsx?$": ["ts-jest", {
      tsconfig: {
        module: "commonjs",
        moduleResolution: "node",
        types: ["jest", "node"],
        noUnusedLocals: false,
      },
    }],
  },
  moduleNameMapper: {
    "^(\\.\\.?/.*)\\.js$": "$1",
  },
};
