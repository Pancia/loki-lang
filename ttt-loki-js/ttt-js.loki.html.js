var loki = (function (){
    var loki = {};

    var sliceArgs = function (args, start) {
        start = typeof start !== 'undefined' ? start : 0;
        return args.length > start ? [].slice.call(args, start) : [];
    };

    var assertIsFunction = function (f) {
        if (typeof f !== "function")
        {throw "loki error: curry expected a function"}
        return f;
    };

    var curry = function (fn) {
        assertIsFunction(fn);
        return function inner() {
            var _args = sliceArgs(arguments);
            if (_args.length === fn.length) {
                return fn.apply(null, _args);
            } else if (_args.length > fn.length) {
                var initial = fn.apply(null, _args);
                return foldl(fn, initial, _args.slice(fn.length));
            } else {
                return function() {
                    var args = sliceArgs(arguments);
                    return inner.apply(null, _args.concat(args));
                };
            }
        };
    };

    var each = curry(function (iterator, items) {
        assertIsFunction(iterator);
        if (items == null || !Array.isArray(items)) {return;}
        items.forEach(function (e, i) {iterator.call(null, e, i)});
    });

    var foldl = curry(function (iterator, acc, xs) {
        assertIsFunction(iterator);
        each(function (x, i) {
            acc = iterator.call(null, acc, x, i);
        }, xs);
        return acc;
    });

    loki.extend = function (destination, source) {
        for (var k in source) {
            if (source.hasOwnProperty(k)) {
                destination[k] = source[k];
            }
        }
        return destination;
    }

    loki.print = function() {
        var _log = function(x) {
            if (typeof console === "object") {console.log(x);}
            else {assertIsFunction(print)(x);}
        };
        var args = sliceArgs(arguments);
        args.forEach(_log);
    };

    loki.get = function(e, i) {return e[i];};
    loki.set = function(x, v) {x = v;};
    loki.assoc = function(x, i, v) {x[i] = v;return x};
    loki.range = function(N) {return Array.apply(null, {length: N}).map(Number.call, Number);};

    //Arithmetic
    loki.plus  = curry(function(x, y) {return x + y});
    loki.minus = curry(function(x, y) {return x - y});
    loki.mult  = curry(function(x, y) {return x * y});
    loki.div   = curry(function(x, y) {return x / y});
    loki.mod   = curry(function(x, y) {return x % y});

    //Logic
    loki.and = curry(function(x, y) {return x && y});
    loki.or  = curry(function(x, y) {return x || y});
    var eq = curry(function(x, y) {return (x === y ? x : false)});
    loki.eq  = function(x,y) {return !!eq(x,y);}
    loki.neq  = function(x,y) {return !eq(x,y);}
    var lt = curry(function(x, y) {return (x < y ? y : false)});
    loki.lt  = function(x,y) {return !!lt(x,y);}
    var lte = curry(function(x, y) {return (x <= y ? y : false)});
    loki.lte  = function(x,y) {return !!lte(x,y);}
    var gt = curry(function(x, y) {return (x > y ? y : false)});
    loki.gt  = function(x,y) {return !!gt(x,y);}
    var gte = curry(function(x, y) {return (x >= y ? y : false)});
    loki.gte  = function(x,y) {return !!gte(x,y);}

    return loki;
})();
//END LOKI HELPER FUNCTIONS
var painted;
var content;
var winningCombos;
var turn = 0;
var c;
var cxt;
var squaresFilled = 0;
var w;
var y;
window.onload = function () {
painted = [];
content = [];
winningCombos = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]];
(typeof $("<h1>Tic Tac Toe</h1>").appendTo === "function" ? $("<h1>Tic Tac Toe</h1>").appendTo("body") : $("<h1>Tic Tac Toe</h1>").appendTo);
return (typeof loki.range(9).forEach === "function" ? loki.range(9).forEach(function (l) {
(typeof (typeof (typeof $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr === "function" ? $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr("width", "50") : $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr).attr === "function" ? (typeof $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr === "function" ? $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr("width", "50") : $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr).attr("height", "50") : (typeof $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr === "function" ? $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr("width", "50") : $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr).attr).appendTo === "function" ? (typeof (typeof $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr === "function" ? $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr("width", "50") : $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr).attr === "function" ? (typeof $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr === "function" ? $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr("width", "50") : $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr).attr("height", "50") : (typeof $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr === "function" ? $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr("width", "50") : $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr).attr).appendTo("body") : (typeof (typeof $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr === "function" ? $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr("width", "50") : $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr).attr === "function" ? (typeof $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr === "function" ? $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr("width", "50") : $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr).attr("height", "50") : (typeof $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr === "function" ? $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr("width", "50") : $("<canvas/>", {style:"border:1px solid black",onclick:loki.plus("canvasClicked(", loki.plus(l, 1), ")"),id:loki.plus("canvas", loki.plus(l, 1))}).attr).attr).appendTo);
(loki.or(loki.eq(l, 2), loki.eq(l, 5))?(typeof $("<br>").appendTo === "function" ? $("<br>").appendTo("body") : $("<br>").appendTo):null);
loki.assoc(painted, l, false);
return loki.assoc(content, l, "")
}) : loki.range(9).forEach)
};
var movePlayer = function (cn) {
(typeof cxt.beginPath === "function" ? cxt.beginPath() : cxt.beginPath);
(typeof cxt.moveTo === "function" ? cxt.moveTo(10, 10) : cxt.moveTo);
(typeof cxt.lineTo === "function" ? cxt.lineTo(40, 40) : cxt.lineTo);
(typeof cxt.moveTo === "function" ? cxt.moveTo(40, 10) : cxt.moveTo);
(typeof cxt.lineTo === "function" ? cxt.lineTo(10, 40) : cxt.lineTo);
(typeof cxt.stroke === "function" ? cxt.stroke() : cxt.stroke);
(typeof cxt.closePath === "function" ? cxt.closePath() : cxt.closePath);
loki.assoc(content, loki.minus(cn, 1), "X");
return onEndTurn(cn)
};
var moveComputer = function (cn) {
(typeof cxt.beginPath === "function" ? cxt.beginPath() : cxt.beginPath);
(typeof cxt.arc === "function" ? cxt.arc(25, 25, 20, 0, loki.mult((typeof Math.PI === "function" ? Math.PI() : Math.PI), 2), true) : cxt.arc);
(typeof cxt.stroke === "function" ? cxt.stroke() : cxt.stroke);
(typeof cxt.closePath === "function" ? cxt.closePath() : cxt.closePath);
loki.assoc(content, loki.minus(cn, 1), "O");
return onEndTurn(cn)
};
var onEndGame = function () {
return (typeof location.reload === "function" ? location.reload(true) : location.reload)
};
var onEndTurn = function (cn) {
turn = loki.plus(turn, 1);
loki.assoc(painted, loki.minus(cn, 1), true);
squaresFilled = loki.plus(squaresFilled, 1);
checkForWinners(loki.get(content, loki.minus(cn, 1)));
return (loki.eq(squaresFilled, 9)?onEndGame():null)
};
var theCanvas;
var canvasClicked = function (cn) {
theCanvas = loki.plus("canvas", cn);
c = (typeof document.getElementById === "function" ? document.getElementById(theCanvas) : document.getElementById);
cxt = (typeof c.getContext === "function" ? c.getContext("2d") : c.getContext);
return (painted[cn - 1] === false?(0 === turn % 2?movePlayer(cn):moveComputer(cn)):loki.print("Invalid move!"))
};
var onVictory = function (sym) {
loki.print(loki.plus(sym, " won!"));
return playAgain()
};
var checkForWinners = function (sym) {
return (typeof loki.range((typeof winningCombos.length === "function" ? winningCombos.length() : winningCombos.length)).forEach === "function" ? loki.range((typeof winningCombos.length === "function" ? winningCombos.length() : winningCombos.length)).forEach(function (a) {
return (loki.and(loki.eq(loki.get(content, loki.get(loki.get(winningCombos, a), 0)), sym), loki.eq(loki.get(content, loki.get(loki.get(winningCombos, a), 1)), sym), loki.eq(loki.get(content, loki.get(loki.get(winningCombos, a), 2)), sym))?onVictory(sym):null)
}) : loki.range((typeof winningCombos.length === "function" ? winningCombos.length() : winningCombos.length)).forEach)
};
var playAgain = function () {
y = confirm("Play again?");
return (loki.eq(y, true)?(typeof location.reload === "function" ? location.reload(true) : location.reload):null)
};