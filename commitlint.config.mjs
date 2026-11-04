export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [1, 'always', ['app', 'home', 'closet', 'shop', 'journey', 'social', 'stats', 'pet', 'widget', 'health', 'content', 'build', 'docs', 'deps']],
  },
};
