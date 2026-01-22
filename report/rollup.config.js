import { readFileSync } from 'fs';
import nodeResolve from '@rollup/plugin-node-resolve';

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'));

function externals(id) {
    return id.indexOf("@hpcc-js/") === 0;
}

export default {
    input: "lib-es6/index",
    external: externals,
    output: {
        file: pkg.main,
        format: "es",
        sourcemap: true,
        name: pkg.name
    },
    plugins: [
        nodeResolve({
            browser: true
        })
    ]
};
