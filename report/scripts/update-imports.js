import { readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = dirname(scriptDir);
const packageJsonPath = join(packageRoot, "package.json");
const htmlPath = join(packageRoot, "res", "index.html");

const packageJson = JSON.parse(await readFile(packageJsonPath, "utf8"));
const packageVersions = {
    ...packageJson.dependencies,
    ...packageJson.devDependencies
};

const esmRunHpccUrl = /https:\/\/esm\.run\/(%40hpcc-js\/[^@/"\s]+|@hpcc-js\/[^@/"\s]+)@([^/"\s]+)/g;
const html = await readFile(htmlPath, "utf8");
const missingPackages = new Set();
let updateCount = 0;

const updatedHtml = html.replace(esmRunHpccUrl, (url, encodedPackageName) => {
    const packageName = encodedPackageName.replace("%40", "@");
    const packageVersion = packageVersions[packageName];

    if (!packageVersion) {
        missingPackages.add(packageName);
        return url;
    }

    const updatedUrl = `https://esm.run/${encodedPackageName}@${packageVersion}`;
    if (updatedUrl !== url) {
        updateCount++;
    }
    return updatedUrl;
});

if (missingPackages.size) {
    throw new Error(`Missing package.json version for: ${Array.from(missingPackages).sort().join(", ")}`);
}

if (updatedHtml !== html) {
    await writeFile(htmlPath, updatedHtml);
}

console.log(`Updated ${updateCount} esm.run package URL${updateCount === 1 ? "" : "s"} in res/index.html`);