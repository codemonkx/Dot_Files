import QtQuick
pragma Singleton

QtObject {
    id: root

    // A plain number is not a calculation: the launcher should not offer
    // "copy 42" when the user types "42".
    function isExpression(text) {
        if (text === undefined || text === null)
            return false;

        let source = String(text).trim();
        if (source.length === 0)
            return false;

        if (/^[+-]?\d+(\.\d+)?$/.test(source))
            return false;

        if (!/[0-9]/.test(source))
            return false;

        if (!/[+\-*/^%()]/.test(source) && !/sqrt|pi/i.test(source))
            return false;

        return evaluate(source) !== null;
    }

    // Recursive descent parser: no eval(), no Function().
    function evaluate(expression) {
        // Declared before the nested parsers so they never read a binding that
        // is only initialised further down (qt.qml.usedbeforedeclared).
        let text = String(expression).replace(/\s+/g, "");
        if (text.length === 0)
            return null;

        let pos = 0;

        function eat(token) {
            if (text.charAt(pos) === token) {
                pos++;
                return true;
            }
            return false;
        }

        function startsWith(token) {
            return text.slice(pos, pos + token.length) === token;
        }

        function parseNumber() {
            let start = pos;
            while (pos < text.length && /[0-9.]/.test(text.charAt(pos)))pos++
            if (start === pos)
                return null;

            let value = parseFloat(text.slice(start, pos));
            return isNaN(value) ? null : value;
        }

        function parsePrimary() {
            if (eat("(")) {
                let inner = parseExpression();
                if (inner === null || !eat(")"))
                    return null;

                return inner;
            }
            if (startsWith("sqrt")) {
                pos += 4;
                let operand = parsePrimary();
                if (operand === null || operand < 0)
                    return null;

                return Math.sqrt(operand);
            }
            if (startsWith("pi")) {
                pos += 2;
                return Math.PI;
            }
            return parseNumber();
        }

        function parseUnary() {
            if (eat("-")) {
                let negated = parseUnary();
                return negated === null ? null : -negated;
            }
            if (eat("+"))
                return parseUnary();

            return parsePrimary();
        }

        function parsePower() {
            let base = parseUnary();
            if (base === null)
                return null;

            if (eat("^")) {
                let exponent = parsePower();
                if (exponent === null)
                    return null;

                return Math.pow(base, exponent);
            }
            return base;
        }

        function parseTerm() {
            let value = parsePower();
            if (value === null)
                return null;

            while (true)
                if (eat("*")) {
                    let right = parsePower();
                    if (right === null)
                        return null;

                    value *= right;
                } else if (eat("/")) {
                    let right = parsePower();
                    if (right === null || right === 0)
                        return null;

                    value /= right;
                } else if (eat("%")) {
                    let right = parsePower();
                    if (right === null || right === 0)
                        return null;

                    value %= right;
                } else {
                    break;
                }

            return value;
        }

        function parseExpression() {
            let value = parseTerm();
            if (value === null)
                return null;

            while (true)
                if (eat("+")) {
                    let right = parseTerm();
                    if (right === null)
                        return null;

                    value += right;
                } else if (eat("-")) {
                    let right = parseTerm();
                    if (right === null)
                        return null;

                    value -= right;
                } else {
                    break;
                }

            return value;
        }

        let result = parseExpression();
        if (result === null || pos !== text.length || !isFinite(result))
            return null;

        return result;
    }

    function format(value) {
        if (value === undefined || value === null || !isFinite(value))
            return "";

        let magnitude = Math.abs(value);
        if (magnitude !== 0 && (magnitude >= 1e+12 || magnitude < 1e-06))
            return value.toExponential(6).replace(/\.?0+e/, "e");

        let rounded = Math.round(value * 1e+06) / 1e+06;
        return String(rounded);
    }

}
