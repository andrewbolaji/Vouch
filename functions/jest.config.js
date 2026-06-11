module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testTimeout: 30000,
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
