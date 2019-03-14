import { QuartileCandlestick } from "@hpcc-js/chart";
import { Widget } from "@hpcc-js/common";
import { Result, Workunit, WUInfo } from "@hpcc-js/comms";
import { Grid } from "@hpcc-js/layout";
import { Html } from "@hpcc-js/other";
import { BreakdownTable, StyledTable } from "@hpcc-js/html";

const knownProfileField = (sch: WUInfo.ECLSchemaItem): boolean => ["attribute", "given_attribute_type", "best_attribute_type", "rec_count", "fill_count", "fill_rate", "cardinality", "cardinality_breakdown", "modes", "min_length", "max_length", "ave_length", "popular_patterns", "rare_patterns", "is_numeric", "numeric_min", "numeric_max", "numeric_mean", "numeric_std_dev", "numeric_lower_quartile", "numeric_median", "numeric_upper_quartile", "numeric_correlations"].indexOf(sch.ColumnName) > 0;
const countProfileFields = (r: Result): number => r.ECLSchemas.ECLSchemaItem.filter(knownProfileField).length;
const isProfileResult = (r: Result, threshold = 4): boolean => countProfileFields(r) >= threshold;

const config = {
    rowHeight: 180,
    primaryFontSize: 20,
    secondaryFontSize: 14,
    primaryColor: "#494949",
    secondaryColor: "#DDD",
    offwhiteColor: "#FBFBFB",
    blueColor: "#1A99D5"
};

export class Test extends Grid {

    _wu: Workunit;
    _data: any[];

    constructor(private _espUrl: string) {
        super();
        this
            .gutter(0)
            .surfaceShadow(false)
            .surfacePadding("0")
            .surfaceBorderWidth(0)
            ;

        const urlParts = this._espUrl.split("/WsWorkunits/res/");
        const baseUrl = urlParts[0];
        const urlParts2 = urlParts[1].split("/report/res/index.html");
        const wuid = urlParts2[0];
        this._wu = Workunit.attach({ baseUrl }, wuid);
    }

    enter(domNode, element) {
        super.enter(domNode, element);
        domNode.style.height = (this._data.length * config.rowHeight) + "px";

        this._data.forEach((row, i) => {
            const subgrid = new Grid()
                .surfaceShadow(false)
                .surfaceBorderWidth(0)
                ;
            const descriptionWidget = getAttributeDescWidget(row);
            const breakdownWidget = getBreakdownWidget(row);
            const statsWidget = getStatsWidget(row);
            subgrid
                .setContent(0, 0, descriptionWidget, undefined, 1, 1)
                .setContent(0, 1, statsWidget, undefined, 1, 1)
                .setContent(0, 2, breakdownWidget, undefined, 1, 1)
                ;
            this
                .setContent(i, 0, subgrid)
                ;
            function getAttributeDescWidget(row) {
                const w1 = new Html()
                    .html(`<span style="
                        padding-top:6px;
                        display:inline-block;
                        font-size:${config.primaryFontSize}px;
                    ">${row.attribute}</span><br/>
                    <span style="
                        color:${config.primaryColor};
                        padding:8px;
                        display:inline-block;
                        font-size:${config.secondaryFontSize}px;
                        margin-top:4px;
                        border:1px solid ${config.secondaryColor};
                        border-radius:4px;
                        background-color: ${config.offwhiteColor};
                    ">
                        <i style="
                            font-size:${config.secondaryFontSize}px;
                            color:${config.blueColor};
                        " class="fa ${row.best_attribute_type.slice(0, 6) === "string" ? "fa-font" : "fa-hashtag"}"></i>
                        ${row.given_attribute_type} (given)
                    </span>
                    <span style="
                        color:${config.primaryColor};
                        padding:8px;
                        display:inline-block;
                        font-size:${config.secondaryFontSize}px;
                        margin-top:4px;
                        border:1px solid ${config.secondaryColor};
                        border-radius:4px;
                        background-color: ${config.offwhiteColor};
                    ">
                        <i style="
                            font-size:${config.secondaryFontSize}px;
                            color:${config.blueColor};
                        " class="fa ${row.best_attribute_type.slice(0, 6) === "string" ? "fa-font" : "fa-hashtag"}"></i>
                        ${row.best_attribute_type} (best)
                    </span>
                    `)
                    .overflowX("hidden")
                    .overflowY("hidden")
                    ;
                const fillRate = row.fill_rate === 100 || row.fill_rate === 0 ? row.fill_rate : row.fill_rate.toFixed(1);
                const w2 = new StyledTable()
                    .data([
                        ["Cardinality", row.cardinality, "~" + (row.cardinality / row.fill_count * 100).toFixed(0) + "%"],
                        ["Filled", row.fill_count, fillRate + "%"],
                    ])
                    .tbodyColumnStyles([
                        { "font-weight": "bold", "font-size": config.secondaryFontSize + "px" },
                        { "font-weight": "normal", "font-size": config.secondaryFontSize + "px" },
                        { "font-weight": "normal", "font-size": config.secondaryFontSize + "px" },
                    ])
                    ;
                const grid = new Grid()
                    .gutter(0)
                    .surfaceShadow(false)
                    .surfacePadding("0")
                    .surfaceBorderWidth(0)
                    .setContent(0, 0, w1, "", 1, 1)
                    .setContent(1, 0, w2, "", 1, 1)
                    ;
                return grid;
            }
            function getBreakdownWidget(row) {
                if (row.cardinality_breakdown.Row.length > 0) {
                    let len = 0;
                    len = row.cardinality_breakdown.Row.length;
                    const _data = row.cardinality_breakdown.Row
                        .map(row => [
                            row.value.trim(),
                            row.rec_count
                        ]);
                    if (len > 4) {
                        return breakdownWidget("Cardinality Breakdown", BreakdownTable, _data);
                    } else {
                        return breakdownWidget("Cardinality Breakdown", StyledTable, _data);
                    }
                } else if (row.is_numeric) {
                    return new QuartileCandlestick()
                        .columns(["Min", "25%", "50%", "75%", "Max"])
                        .data([
                            row.numeric_min,
                            row.numeric_lower_quartile,
                            row.numeric_median,
                            row.numeric_upper_quartile,
                            row.numeric_max
                        ])
                        .edgePadding(30)
                        .dataHeight(20)
                        .roundedCorners(1)
                        .lineWidth(1)
                        ;
                } else if (row.popular_patterns.Row.length > 0) {
                    const _data = row.popular_patterns.Row
                        .map(row => [
                            row.data_pattern.trim(),
                            row.rec_count
                        ]);
                    return breakdownWidget("Popular Patterns", BreakdownTable, _data);
                }
                function breakdownWidget(title, proto, _data) {
                    return new proto()
                        .columns([title, ""])
                        .theadColumnStyles([
                            {
                                "text-align": "left",
                                "font-size": config.secondaryFontSize + "px"
                            }
                        ])
                        .data(_data)
                        ;
                }
            }
            function getStatsWidget(row) {
                if (row.is_numeric) {
                    return new StyledTable()
                        .data([
                            ["Mean", row.numeric_mean, ""],
                            ["Std. Deviation", row.numeric_std_dev, ""],
                            ["", "", ""],
                            ["Quantiles", row.numeric_min, "Min"],
                            ["", row.numeric_lower_quartile, "25%"],
                            ["", row.numeric_median, "50%"],
                            ["", row.numeric_upper_quartile, "75%"],
                            ["", row.numeric_max, "Max"],
                        ])
                        .tbodyColumnStyles([
                            { "font-weight": "bold" },
                            { "font-weight": "normal" },
                            { "font-weight": "normal" },
                        ])
                        ;
                } else if (row.popular_patterns.Row.length > 0) {
                    return new StyledTable()
                        .data([
                            ["Min Length", row.min_length, ""],
                            ["Avg Length", row.ave_length, ""],
                            ["Max Length", row.max_length, ""]
                        ])
                        .tbodyColumnStyles([
                            { "font-weight": "bold" },
                            { "font-weight": "normal" },
                            { "font-weight": "normal" },
                        ])
                        ;
                }
                return getAttributeDescWidget(row);
            }
        })
    }

    update(domNode, element) {
        super.update(domNode, element);
    }

    render(callback?: (w: Widget) => void): this {
        this._wu.fetchResults().then(results => {
            for (const result of results) {
                if (isProfileResult(result)) {
                    return result;
                }
            }
        }).then((result?: Result) => {
            if (result) {
                return result.fetchRows();
            }
            return [];
        }).then(rows => {
            this._data = rows;
            super.render(w => {
                if (callback) {
                    callback(this);
                }
            });
        });
        return this;
    }
}
