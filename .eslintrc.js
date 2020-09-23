module.exports = {
    'env': {
        'browser': true,
        'commonjs': true,
        'es6': true,
    },
    'extends': [
        'eslint:recommended',
        'plugin:react/recommended',
        'plugin:@typescript-eslint/eslint-recommended',
    ],
    'globals': {
        'Atomics': 'readonly',
        'SharedArrayBuffer': 'readonly',
    },
    'parser': '@typescript-eslint/parser',
    'parserOptions': {
        'ecmaFeatures': {
            'jsx': true,
        },
        'ecmaVersion': 2020,
        'sourceType': 'module',
    },
    'plugins': [
        'react',
        '@typescript-eslint',
    ],
    'rules': {
        'no-empty': ['error', { 'allowEmptyCatch': true }],
        'prefer-template': 'error',
        'indent': [
            'error',
            4,
            { 'SwitchCase': 1 },
        ],
        'linebreak-style': [
            'error',
            'unix',
        ],
        'quotes': [
            'error',
            'single',
        ],
        'semi': [
            'error',
            'never',
        ],
        'no-unused-vars': 'off',
        '@typescript-eslint/no-unused-vars': 'error',
    },
}
