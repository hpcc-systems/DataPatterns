import nodeResolve from 'rollup-plugin-node-resolve';

const pkg = require("./package.json");

function externals(id) {
    return !!pkg.dependencies[id];
}

function globals(id) {
    if (id.indexOf("@hpcc-js") === 0) {
        return id;
    }
    return undefined;
}

export default {
    input: "lib-es6/index",
    external: externals,
    output: {
        file: pkg.main,
        format: "amd",
        sourcemap: true,
        globals: globals,
        name: pkg.name
    },
    plugins: [
        nodeResolve()
    ]
};
