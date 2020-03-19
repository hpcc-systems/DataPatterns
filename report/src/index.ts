import { Widget } from "@hpcc-js/common";
import { Result, Workunit, WUInfo } from "@hpcc-js/comms";
import { DockPanel } from "@hpcc-js/phosphor";
import { Report } from "./Report";

const knownProfileField = (sch: WUInfo.ECLSchemaItem): boolean => ["attribute", "given_attribute_type", "best_attribute_type", "rec_count", "fill_count", "fill_rate", "cardinality", "cardinality_breakdown", "modes", "min_length", "max_length", "ave_length", "popular_patterns", "rare_patterns", "is_numeric", "numeric_min", "numeric_max", "numeric_mean", "numeric_std_dev", "numeric_lower_quartile", "numeric_median", "numeric_upper_quartile", "correlations"].indexOf(sch.ColumnName) > 0;
const countProfileFields = (r: Result): number => r.ECLSchemas.ECLSchemaItem.filter(knownProfileField).length;
const isProfileResult = (r: Result): boolean => countProfileFields(r) >= 4;

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
        if (!this._prevFetch) {
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
                        resultReports.forEach((r: any, i) => {
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
            .then(() => {
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
