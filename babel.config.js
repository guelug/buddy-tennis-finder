module.exports = function (api) {
  api.cache(true);
  return {
    presets: ["babel-preset-expo"],
    plugins: [
      [
        "module-resolver",
        {
          root: ["./"],
          alias: {
            "@": "./src"
          }
        }
      ],
      // Reanimated DEBE ser el último plugin (requisito oficial).
      "react-native-reanimated/plugin"
    ]
  };
};
