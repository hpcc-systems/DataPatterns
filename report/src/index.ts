import { Widget } from "@hpcc-js/common";
import { Result, Workunit, WUInfo } from "@hpcc-js/comms";
import { Grid } from "@hpcc-js/layout";
import { Html } from "@hpcc-js/other";
import { DockPanel } from "@hpcc-js/phosphor";
import { BreakdownTable, StyledTable } from "@hpcc-js/html";
import { StatChart } from "./statChart";

const knownProfileField = (sch: WUInfo.ECLSchemaItem): boolean => ["attribute", "given_attribute_type", "best_attribute_type", "rec_count", "fill_count", "fill_rate", "cardinality", "cardinality_breakdown", "modes", "min_length", "max_length", "ave_length", "popular_patterns", "rare_patterns", "is_numeric", "numeric_min", "numeric_max", "numeric_mean", "numeric_std_dev", "numeric_lower_quartile", "numeric_median", "numeric_upper_quartile", "numeric_correlations"].indexOf(sch.ColumnName) > 0;
const countProfileFields = (r: Result): number => r.ECLSchemas.ECLSchemaItem.filter(knownProfileField).length;
const isProfileResult = (r: Result): boolean => countProfileFields(r) >= 4;

const config = {
    rowHeight: 190,
    colRatios: {
        attributeDesc: 1,
        statsData: 1,
        breakdown: 2 / 3,
        quartile: 1,
        popularPatterns: 1
    },
    primaryFontSize: 20,
    secondaryFontSize: 14,
    primaryColor: "#494949",
    secondaryColor: "#DDD",
    offwhiteColor: "#FBFBFB",
    blueColor: "#1A99D5",
    redColor: "#ED1C24"
};

export class ReportTabs extends DockPanel {
    _wu: Workunit;
    constructor(private _espUrl: string) {
        super();
        this.hideSingleTabs(true);
        const urlParts = this._espUrl.split("/WsWorkunits/res/");
        const baseUrl = urlParts[0];
        const urlParts2 = urlParts[1].split("/report/res/index.html");
        const wuid = urlParts2[0];
        this._wu = Workunit.attach({ baseUrl }, wuid);
    }
    _prevFetch;
    render(callback?: (w: Widget) => void): this {
        if(!this._prevFetch){
            this._prevFetch = this._wu.fetchResults()
                .then(results => {
                    Promise.all(results.filter(isProfileResult).map(result => {
                            return result.fetchRows().then(rows => {
                                return {
                                    result,
                                    report: new Report(rows)
                                }
                            });
                        })).then((resultReports: any) => {
                            resultReports.forEach((r: any,i) => {
                                if (i === 0) {
                                    this.addWidget(r.report, r.result.Name);
                                } else {
                                    this.addWidget(r.report, r.result.Name, "tab-after", resultReports[i - 1].report);
                                }
                            });
                        });
                });
        }
        this._prevFetch
            .then(()=>{
                super.render(w => {
                    if (callback) {
                        callback(this as any);
                    }
                });
            })
            ;
        return this;
    }
}

export interface ReportTabs {
    hideSingleTabs(): boolean;
    hideSingleTabs(_: boolean): this;
    addWidget(_: any, _2?: string, _3?: string, _4?: any): this;
}

export class Report extends Grid {

    _data: any[];
    _fixedHeight?: number;
    _showBreakdownColumn = true;
    _showPopularPatternsColumn = true;
    _showQuartileColumn = true;

    constructor(data) {
        super();
        this._data = data;
        this
            .gutter(12)
            .surfaceShadow(false)
            .surfacePadding("0")
            .surfaceBorderWidth(0)
            ;
    }

    enter(domNode, element) {
        this._fixedHeight = this._data.length * config.rowHeight;
        domNode.style.height = this._fixedHeight + "px";
        this.height(this._fixedHeight);
        super.enter(domNode, element);
        const statsDataWidth = this.calcStatsWidgetDataColumnWidth();
        this._showQuartileColumn = this._data.filter(row => row.is_numeric).length > 0;
        this._showBreakdownColumn = this._data.filter(row => row.cardinality_breakdown.Row.length > 0).length > 0;
        this._showPopularPatternsColumn = this._data.filter(row => row.popular_patterns.Row.length > 0).length > 0;
        let colCount = 3;
        this._data.forEach((row, i) => {
            const cc = this.enterDataRow(row, i, { statsDataWidth });
            if (cc > colCount) {
                colCount = cc;
            }
        });
        element.classed("report-col-count-" + colCount, true);
    }

    enterDataRow(row, i, ext) {
        const y = i * config.rowHeight;

        let c = 2;
        let cPos = 0;
        let cStep = 12;
        this.setContent(y, cPos, getAttributeDescWidget(row), undefined, config.rowHeight, cStep * config.colRatios.attributeDesc);
        cPos += cStep * config.colRatios.attributeDesc;
        this.setContent(y, cPos, getStatsWidget(row, ext.statsDataWidth), undefined, config.rowHeight, cStep * config.colRatios.statsData);
        cPos += cStep * config.colRatios.statsData;
        if (this._showQuartileColumn) {
            this.setContent(y, cPos, getQuartileWidget(row), undefined, config.rowHeight, cStep * config.colRatios.quartile);
            cPos += cStep * config.colRatios.quartile;
            ++c;
        }
        if (this._showBreakdownColumn) {
            this.setContent(y, cPos, getBreakdownWidget(row), undefined, config.rowHeight, cStep * config.colRatios.breakdown);
            cPos += cStep * config.colRatios.breakdown;
            ++c;
        }
        if (this._showPopularPatternsColumn) {
            this.setContent(y, cPos, getPopularPatternsWidget(row), undefined, config.rowHeight, cStep * config.colRatios.popularPatterns);
            cPos += cStep * config.colRatios.popularPatterns;
            ++c;
        }
        return c;

        function getAttributeDescWidget(row) {
            const p = 8;
            const b = 1;
            const w1 = new Html()
                .html(`<span style="
                    color:${config.primaryColor};
                    padding:${p}px;
                    display:inline-block;
                    font-size:${config.secondaryFontSize}px;
                    margin-top:4px;
                    border:${b}px solid ${config.secondaryColor};
                    border-radius:4px;
                    background-color: ${config.offwhiteColor};
                    width: calc(100% - ${(p * 2) + (b * 2)}px);
                ">
                    <i style="
                        font-size:${config.secondaryFontSize}px;
                        color:${config.blueColor};
                    " class="fa ${row.given_attribute_type.slice(0, 6) === "string" ? "fa-font" : "fa-hashtag"}"></i>
                    <b>${row.attribute}</b>
                    <span style="float:right;">${row.given_attribute_type}</span>
                </span>
                <span style="padding:12px 2px;display:inline-block;font-family: Verdana; color: rgb(51, 51, 51); font-weight: bold; font-size: 14px;">
                    Optimal:
                </span>
                <span style="
                    color:${config.primaryColor};
                    padding:4px 8px;
                    display:inline-block;
                    font-size:${config.secondaryFontSize}px;
                    margin-top:4px;
                    border:1px solid ${config.secondaryColor};
                    border-radius:4px;
                    background-color: ${config.offwhiteColor};
                    float:right;
                ">
                    <i style="
                        font-size:${config.secondaryFontSize}px;
                        color:${config.blueColor};
                    " class="fa ${row.best_attribute_type.slice(0, 6) === "string" ? "fa-font" : "fa-hashtag"}"></i>
                    ${row.best_attribute_type}
                </span>
                `)
                .overflowX("hidden")
                .overflowY("hidden")
                ;
            let fillRate = row.fill_rate === 100 || row.fill_rate === 0 ? row.fill_rate : row.fill_rate.toFixed(1);
            const w2 = new StyledTable()
                .data([
                    ["Cardinality", row.cardinality, "(~" + (row.cardinality / row.fill_count * 100).toFixed(0) + "%)"],
                    ["Filled", row.fill_count, "(" + fillRate + "%)"],
                ])
                .tbodyColumnStyles([
                    { "font-weight": "bold", "font-size": config.secondaryFontSize + "px", "width": "1%" },
                    { "font-weight": "normal", "font-size": config.secondaryFontSize + "px", "text-align": "right", "width": "auto" },
                    { "font-weight": "normal", "font-size": config.secondaryFontSize + "px", "text-align": "left", "width": "1%" },
                ])
                ;
            const grid = new Grid()
                .gutter(0)
                .surfaceShadow(false)
                .surfacePadding("0")
                .surfaceBorderWidth(0)
                .setContent(0, 0, w1)
                .setContent(1, 0, w2)
                ;
            return grid;
        }
        function getBreakdownWidget(row) {
            if (row.cardinality_breakdown.Row.length > 0) {
                return new BreakdownTable()
                    .columns(["Cardinality", ""])
                    .data(
                        row.cardinality_breakdown.Row
                            .map(row => [
                                row.value.trim(),
                                row.rec_count
                            ])
                    )
                    .theadColumnStyles([
                        {
                            "text-align": "left",
                            "font-size": config.secondaryFontSize + "px",
                            "white-space": "nowrap"
                        }
                    ])
                    .tbodyColumnStyles([
                        {
                            "max-width": "60px",
                            "overflow": "hidden",
                            "text-overflow": "ellipsis",
                            "white-space": "nowrap",
                        },
                        {
                            "text-align": "right",
                            "font-size": config.secondaryFontSize + "px"
                        }
                    ])
                    ;
            } else {
                return getNotAvailableWidget("Cardinality Breakdown", "N/A");
            }
        }
        function getStatsWidget(row, dataWidth) {
            if (row.is_numeric) {
                return new StyledTable()
                    .data([
                        ["Mean", row.numeric_mean, ""],
                        ["Std. Deviation", row.numeric_std_dev, ""],
                        ["", "", ""],
                        ["Quartiles", row.numeric_min, "Min"],
                        ["", row.numeric_lower_quartile, "25%"],
                        ["", row.numeric_median, "50%"],
                        ["", row.numeric_upper_quartile, "75%"],
                        ["", row.numeric_max, "Max"],
                    ])
                    .tbodyColumnStyles([
                        { "font-weight": "bold", "text-align": "right", "width": "100px" },
                        { "font-weight": "normal", "width": dataWidth + "px" },
                        { "font-weight": "normal", "width": "auto" },
                    ])
                    ;
            } else if (row.popular_patterns.Row.length > 0) {
                return new StyledTable()
                    .data([
                        ["Min Length", row.min_length],
                        ["Avg Length", row.ave_length],
                        ["Max Length", row.max_length]
                    ])
                    .tbodyColumnStyles([
                        { "font-weight": "bold", "text-align": "right", "width": "100px" },
                        { "font-weight": "normal", "width": "auto" },
                    ])
                    ;
            }
            return getAttributeDescWidget(row);
        }
        function getPopularPatternsWidget(row) {
            if (row.popular_patterns.Row.length > 0) {
                return new BreakdownTable()
                    .columns(["Popular Patterns", ""])
                    .theadColumnStyles([
                        {
                            "text-align": "left",
                            "font-size": config.secondaryFontSize + "px",
                            "white-space": "nowrap"
                        }
                    ])
                    .tbodyColumnStyles([
                        {
                            "max-width": "60px",
                            "overflow": "hidden",
                            "text-overflow": "ellipsis",
                            "white-space": "nowrap",
                        },
                        {
                            "text-align": "right",
                            "font-size": config.secondaryFontSize + "px"
                        }
                    ])
                    .data(
                        row.popular_patterns.Row
                            .map(row => [
                                row.data_pattern.trim(),
                                row.rec_count
                            ])
                    );
            } else {
                return getNotAvailableWidget("Popular Patterns", "N/A");
            }
        }
        function getQuartileWidget(row) {
            if (row.is_numeric) {
                return new StatChart()
                    //.columns(["Min", "25%", "50%", "75%", "Max"])
                    .mean(row.numeric_mean)
                    .standardDeviation(row.numeric_std_dev)
                    .quartiles([
                        row.numeric_min,
                        row.numeric_lower_quartile,
                        row.numeric_median,
                        row.numeric_upper_quartile,
                        row.numeric_max
                    ])
                    ;
            } else {
                return getNotAvailableWidget("Quartile", "N/A");
            }
        }
        function getNotAvailableWidget(message, submessage) {
            return new Html()
                .html(`
                    <b style="line-height:23px;font-size:${config.secondaryFontSize}px;color: rgb(51, 51, 51);">${message}</b>
                    <br/>
                    <i style="font-size:${config.secondaryFontSize}px;color: rgb(51, 51, 51);">${submessage}</i>
                `)
                .overflowX("hidden")
                .overflowY("hidden")
                ;
        }
    }

    update(domNode, element) {
        this.height(this._fixedHeight);
        super.update(domNode, element);
    }

    resize(size?) {
        const retVal = super.resize(size);
        if (this._placeholderElement) {
            this._placeholderElement
                .style("height", (this._fixedHeight ? this._fixedHeight : this._size.height) + "px")
                ;
        }
        return retVal;
    }

    calcStatsWidgetDataColumnWidth() {
        let ret = 0;
        this._data.forEach(row => {
            const _w = Math.max(
                this.textSize(row.numeric_mean).width,
                this.textSize(row.numeric_std_dev).width,
                this.textSize(row.numeric_min).width,
                this.textSize(row.numeric_lower_quartile).width,
                this.textSize(row.numeric_median).width,
                this.textSize(row.numeric_upper_quartile).width,
                this.textSize(row.numeric_max).width
            );
            if (_w > ret) {
                ret = _w;
            }
        });
        return ret;
    }
}
