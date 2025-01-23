"use strict";
// 逆波兰表达式计算 Reverse Polish Notation（Notation表达式）
// 参考文章：https://my.oschina.net/emacs_8502354/blog/16539058  a + b * (c - d) / e 逆波兰表示为 a b c d - * e / + 文章中写错了
// evaluateExpression函数用于把 逆波兰表达式数据 转换成 我想要的计算表达式，然后返回重新生成的表达式
//      + 转换成 tool.add(a, b)
//      - 转换成 tool.subtract(a, b)
//      * 转换成 tool.multiply(a, b)
//     / 转换成 tool.divide(a, b)
// ts 转 js
// tsc -p tsconfig.json

/**
 * java代码分词
 * @param input 字符串
 * @returns {[{ type: "comment", value: comment }]}
 */
function tokenizeJavaCode(input) {
    const keywords = new Set([
        "class", "interface", "public", "private", "protected", "static", "void", "int",
        "double", "boolean", "return", "if", "else", "for", "while", "do", "try", "catch",
        "finally", "new", "null", "true", "false", "this", "super",
    ]);

    const operators = new Set(["+", "-", "*", "/", "=", "==", "!=", ">", "<", ">=", "<=", "&&", "||", "!", "->"]);
    const brackets = {
        "(": "parenthesis",
        ")": "parenthesis",
        "{": "brace",
        "}": "brace",
        "[": "bracket",
        "]": "bracket"
    };

    const tokens = [];
    let i = 0;

    while (i < input.length) {
        const char = input[i];

        // Skip whitespace
        if (/\s/.test(char)) {
            i++;
            continue;
        }

        // Parse comments
        if (char === "/" && input[i + 1] === "/") {
            let comment = "";
            i += 2;
            while (i < input.length && input[i] !== "\n") {
                comment += input[i++];
            }
            tokens.push({type: "comment", value: comment});
            continue;
        } else if (char === "/" && input[i + 1] === "*") {
            let comment = "";
            i += 2;
            while (i < input.length && !(input[i] === "*" && input[i + 1] === "/")) {
                comment += input[i++];
            }
            i += 2; // Skip "*/"
            tokens.push({type: "comment", value: comment});
            continue;
        }

        // Parse strings
        if (char === '"' || char === "'") {
            let string = char;
            const quoteType = char;
            i++;
            while (i < input.length) {
                string += input[i];
                if (input[i] === quoteType && input[i - 1] !== "\\") break; // End of string
                i++;
            }
            i++;
            tokens.push({type: "string", value: string});
            continue;
        }

        // Parse regex
        if (char === '/' && (tokens.length === 0 || tokens[tokens.length - 1].type === "operator")) {
            let regex = "/";
            i++;
            while (i < input.length && input[i] !== "/") {
                regex += input[i++];
            }
            regex += "/";
            i++;
            tokens.push({type: "regex", value: regex});
            continue;
        }

        // Parse numbers
        if (/\d/.test(char)) {
            let number = "";
            while (i < input.length && /[\d.]/.test(input[i])) {
                number += input[i++];
            }
            tokens.push({type: "number", value: number});
            continue;
        }

        // Parse operators
        const twoCharOp = input.slice(i, i + 2);
        const oneCharOp = input[i];
        if (operators.has(twoCharOp)) {
            tokens.push({type: "operator", value: twoCharOp});
            i += 2;
            continue;
        } else if (operators.has(oneCharOp)) {
            tokens.push({type: "operator", value: oneCharOp});
            i++;
            continue;
        }

        // Parse brackets
        if (brackets[char]) {
            tokens.push({type: brackets[char], value: char});
            i++;
            continue;
        }

        // Parse identifiers and keywords
        if (/[a-zA-Z_]/.test(char)) {
            let identifier = "";
            while (i < input.length && /[a-zA-Z0-9_]/.test(input[i])) {
                identifier += input[i++];
            }
            const type = keywords.has(identifier) ? "keyword" : "identifier";
            tokens.push({type, value: identifier});
            continue;
        }

        // Unknown character
        tokens.push({type: "unknown", value: char});
        i++;
    }
    return tokens;
}

// 检查是否为操作符
function isOperator(char) {
    const operator = ['+', '-', '*', '/'];
    // @ts-ignore
    return operator.includes(char);
}

/**
 * <p>对象属性访问表达式</p>
 * <p>isValidVariableNameOrChain('formData.pa'); // true</p>
 * <p>isValidVariableNameOrChain('myVariable123'); // true</p>
 * <p>isValidVariableNameOrChain('123variable'); // false</p>
 * <p>isValidVariableNameOrChain('$special_Name'); // true</p>
 * <p>isValidVariableNameOrChain('var.with.dot'); // true</p>
 * <p>isValidVariableNameOrChain('.leadingDot'); // false</p>
 * <p>isValidVariableNameOrChain('trailingDot.'); // false</p>
 * @param name
 * @returns {boolean}
 */
function isValidVariableNameOrChain(name) {
    const regex = /^(?!\d)[\w$]+(\.[\w$]+)*$/;
    return regex.test(name);
}

/**
 * 正则表达式的解释：
 *
 * ^-?：匹配字符串开头，可选的负号 -。
 * (0|[1-9]\d*)：匹配一个 0 或者任意数量的非零数字后面跟任意数量的数字（确保没有前导零）。
 * (\.\d+)?：可选部分，匹配一个小数点后跟随至少一个数字。
 *
 * @param str
 * @returns {boolean}
 */
function isStrictNumeric(str) {
    const regex = /^-?(0|[1-9]\d*)(\.\d+)?$/;
    return regex.test(str);
}

// 四则运算逆波兰表达式转换工具
class FourFundamentaExpression {
    constructor(expression) {
        this.precedence = {"+": 1, "-": 1, "*": 2, "/": 2};
        this.expression = expression;
    }

    /**
     * 将中缀表达式转换为后缀表达式 (逆波兰表示法)
     * @param expression 已经单词划分为数组
     */
    infixToPostfix(expression) {
        const outputQueue = [];
        const operatorStack = [];
        for (let i = 0; i < expression.length; i++) {
            let char = expression[i];
            if (isStrictNumeric(char)) {
                outputQueue.push(char);
            } else if (isValidVariableNameOrChain(char)) {
                // 如果是变量
                outputQueue.push("formData." + char);
            } else if (isOperator(char) || char === '(' || char === ')') {
                // 如果是操作符号 或者 (、)
                if (char === '(') {
                    operatorStack.push(char);
                } else if (char === ')') {
                    while (operatorStack.length && operatorStack[operatorStack.length - 1] !== '(') {
                        outputQueue.push(operatorStack.pop());
                    }
                    operatorStack.pop(); // 移除 '('
                } else if (isOperator(char)) {
                    while (operatorStack.length && operatorStack[operatorStack.length - 1] !== '(' &&
                    this.precedence[char] <= this.precedence[operatorStack[operatorStack.length - 1]]) {
                        outputQueue.push(operatorStack.pop());
                    }
                    operatorStack.push(char);
                }
            }
        }
        while (operatorStack.length) {
            outputQueue.push(operatorStack.pop());
        }
        return outputQueue;
    }

    /**
     * 计算后缀表达式， 我这里自定义的处理方法
     * @param postfix 后缀表达式数组
     */
    evaluatePostfix(postfix) {
        const stack = [];
        postfix.forEach(token => {
            if (isValidVariableNameOrChain(token) || isStrictNumeric(token)) {
                stack.push(token);
            } else if (isOperator(token)) {
                const b = stack.pop();
                const a = stack.pop();
                switch (token) {
                    case '+':
                        stack.push(`tool.add(${a}, ${b})`);
                        break;
                    case '-':
                        stack.push(`tool.subtract(${a}, ${b})`);
                        break;
                    case '*':
                        stack.push(`tool.multiply(${a}, ${b})`);
                        break;
                    case '/':
                        stack.push(`tool.divide(${a}, ${b})`);
                        break;
                }
            }
        });
        return stack[0];
    }

    /**
     * 解析并计算表达式
     * @param expression 字符串 或者 划分好的 表达式 数组
     * @returns {*}
     */
    transferExpression(expression) {
        // 判断expression是否是数组
        let words;
        if (Array.isArray(expression)) {
            words = expression;
        } else {
            words = tokenizeJavaCode(expression);
            words = words.map((item) => item.value);
        }
        // 转换为后缀表达式 (逆波兰表示法)
        const postfix = this.infixToPostfix(words);
        // 计算后缀表达式
        return this.evaluatePostfix(postfix);
    }
}

class BooleanExpression {
    constructor() {
        // 定义运算符及其优先级和关联性
        this.booleanOperators = {
            '!': {precedence: 3, associativity: 'right', type: 'unary'},
            '&&': {precedence: 2, associativity: 'left', type: 'binary'},
            '||': {precedence: 1, associativity: 'left', type: 'binary'}
        };
        // 比较运算符及其优先级（假设所有比较运算符的优先级相同）
        this.comparisonOperators = ['==', '!=', '<', '>', '<=', '>='];
    }

    // 判断是否为布尔操作符
    isBooleanOperator(token) {
        // @ts-ignore
        return token in this.booleanOperators || this.comparisonOperators.includes(token);
    }

    /**
     * 将中缀表达式转换为后缀表达式 (逆波兰表示法)
     * @param expression 已经单词划分为数组
     */
    infixToPostfix(expression) {
        const outputQueue = [];
        const operatorStack = [];
        for (let i = 0; i < expression.length; i++) {
            const char = expression[i];
            if (char === ' ')
                continue;
            if (isValidVariableNameOrChain(char)) {
                // 处理标识符或常量
                outputQueue.push("formData." + char)
            } else if (isStrictNumeric(char)) {
                outputQueue.push(char);
            } else if (char === '(') {
                operatorStack.push(char);
            } else if (char === ')') {
                while (operatorStack.length && operatorStack[operatorStack.length - 1] !== '(') {
                    outputQueue.push(operatorStack.pop());
                }
                operatorStack.pop(); // 移除 '('
            } else if (this.isBooleanOperator(char)) {
                while (operatorStack.length && operatorStack[operatorStack.length - 1] !== '(' &&
                ((this.booleanOperators[char].associativity === 'left' && this.booleanOperators[char].precedence <= this.booleanOperators[operatorStack[operatorStack.length - 1]].precedence) ||
                    (this.booleanOperators[char].associativity === 'right' && this.booleanOperators[char].precedence < this.booleanOperators[operatorStack[operatorStack.length - 1]].precedence))) {
                    outputQueue.push(operatorStack.pop());
                }
                operatorStack.push(char);
            }
        }

        while (operatorStack.length) {
            outputQueue.push(operatorStack.pop());
        }
        return outputQueue;
    }

    /**
     * 计算后缀表达式， 我这里自定义的处理方法
     * @param postfix 后缀表达式数组
     */
    evaluatePostfix(postfix) {
        const stack = [];
        postfix.forEach(token => {
            if (token === 'true' || token === 'false') {
                stack.push(token);
            } else if (isValidVariableNameOrChain(token)) {
                stack.push(token);
            } else if (isStrictNumeric(token)) {
                stack.push(token);
            } else if (token in this.booleanOperators) {
                const b = stack.pop();
                const a = this.booleanOperators[token].type === 'binary' ? stack.pop() : null;
                switch (token) {
                    case '&&':
                        stack.push(`${a} && ${b}`);
                        break;
                    case '||':
                        stack.push(`${a} || ${b}`);
                        break;
                    case '!':
                        stack.push(`!${b}`);
                        break;
                }
            } else { // @ts-ignore
                if (this.comparisonOperators.includes(token)) {
                    const b = stack.pop();
                    const a = stack.pop();
                    switch (token) {
                        case '==':
                            stack.push(`${a} == ${b}`);
                            break;
                        case '!=':
                            stack.push(`${a} != ${b}`);
                            break;
                        case '<':
                            stack.push(`${a} < ${b}`);
                            break;
                        case '>':
                            stack.push(`${a} > ${b}`);
                            break;
                        case '<=':
                            stack.push(`${a} <= ${b}`);
                            break;
                        case '>=':
                            stack.push(`${a} >= ${b}`);
                            break;
                    }
                } else {
                    throw new Error(`Unknown token: ${token}`);
                }
            }
        });
        if (stack.length !== 1) {
            throw new Error("Invalid expression");
        }
        return stack[0];
    }

    transferExpression(expression) {
        let words;
        if (Array.isArray(expression)) {
            words = expression;
        } else {
            words = tokenizeJavaCode(expression);
            words = words.map((item) => item.value);
        }
        // 转换为后缀表达式
        const postfix = this.infixToPostfix(words);
        // 计算后缀表达式的值
        return this.evaluatePostfix(postfix);
    }
}
