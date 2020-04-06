### DataPatterns

DataPatterns is an ECL bundle that provides some basic data profiling and
research tools to an ECL programmer.

### Table of Contents

  * [Installation](#installation)
  * [Release Notes](#release_notes)
  * [Profile()](#profile)
  * [Summary Report with Graphs](#summary_report_with_graphs)
  * [NormalizeProfileResults()](#normalizeprofileresults)
  * [BestRecordStructure()](#bestrecordstructure)
  * [Testing](#testing)

<a name="installation"></a>
### Installation

**Note:**  `DataPatterns.Profile()` and `DataPatterns.BestRecordStructure()` are
now included in HPCC version 7.4.0!  They have been added to the ECL Standard
Library (`Std.DataPatterns`) and also integrated with ECL Watch so you can
create a profile from a saved logical file using only a web browser.  Note that
the Std library version of Profile() will create a visualization of the results
only when executed from ECL Watch; visualizations will not be generated if
Profile() is called from ECL code.  If that is important to you, install this
bundle version instead (they coexist peacefully).

This code is installed as an ECL Bundle.  Complete instructions for managing ECL
Bundles can be found in [The ECL IDE and HPCC Client
Tools](https://d2wulyp08c6njk.cloudfront.net/releases/CE-Candidate-7.6.0/docs/EN_US/TheECLIDEandHPCCClientTools_EN_US-7.6.0-1.pdf)
documentation.

Use the ecl command line tool to install this bundle:

    ecl bundle install https://github.com/hpcc-systems/DataPatterns.git

You may have to either navigate to the client tools bin directory before
executing the command, or use the full path to the ecl tool.

After installation, all of the code here becomes available after you import it:

    IMPORT DataPatterns;

Note that is possible to use this code without installing it as a bundle.  To do
so, simply make it available within your IDE and just ignore the Bundle.ecl
file. With the Windows IDE, the DataPatterns directory must not be a top-level
item in your repository list; it needs to be installed one level below the top
level, such as within your "My Files" folder.

<a name="release_notes"></a>
### Release Notes

|Version|Notes|
|:----:|:-----|
|1.0.0|Initial public release, finally with support for datasets defined using dynamic record lookup|
|1.0.1|Add `ProfileFromPath` and `BestRecordStructureFromPath`; ave\_length bug fix|
|1.0.2|Change attribute field in CorrelationsRec embedded dataset to STRING|
|1.1.0|Add record count breakdown for low-cardinality field values; ProfileFromPath() returns correct record structure|
|1.1.1|Examine UTF8 values for alternate best\_attribute\_type data types rather than just passing them through|
|1.2.0|Add option to emit a suitable TRANSFORM function to BestRecordStructure and BestRecordStructureFromPath|
|1.2.1|Just-sprayed CSV files now supported within BestRecordStructureFromPath|
|1.2.2|Bug fix: Support datasets that contain reserved words as field names (e.g. loop)|
|1.3.0|Support for embedded child records; bug fix for proper computing of upper quartile value|
|1.3.1|Just-sprayed CSV files now supported within ProfileFromPath|
|1.3.2|Allow most CSV attributes to acquire default values in ProfileFromPath and BestRecordStructureFromPath|
|1.3.3|Add file kind gathering back to the code in ProfileFromPath and BestRecordStructureFromPath (regression from 1.3.2)|
|1.3.4|When given explicit numeric attribute types, refrain from recommending a "best" attribute type|
|1.3.5|Fix ordering of output in BestRecordStructure when TRANSFORM is emitted|
|1.4.0|Automatically include improved visual results of Profile, including data distribution graphs (within workunit's Resources tab)|
|1.4.1|Regression: Fix self-tests that were failing due to changes in v1.3.4|
|1.4.2|String fields containing all numerics with leading zeros are now marked as string in best\_attribute\_type; string fields where the length varies by more than three orders of magnitude are now marked as string in best\_attribute\_type|
|1.5.0|Add support for SET OF data types and child datasets|
|1.5.1|Support for tabbed visual results of multiple profiles in a workunit's result; changes to avoid symbol collision in calling ECL code; visual report styling update|
|1.5.2|Import the ECL Standard Library within the Profile() function macro so callers do not have to|
|1.5.3|Fix leading-zero numeric test, ensuring that only all-numeric values are considered as string type candidates|
|1.5.4|Fix tab issues that appeared when multiple profiling results were available|
|1.5.5|Fix visualized report vertical scrolling problems; update dependency to resolve security issue; removed erroneous HTML fragment from reports|
|1.5.7|Add NormalizeProfileResults() function macro (see below for details); fix ECL compiler problem accessing child datasets hosted within embedded child records; make sure empty child dataset information appears in the final output|
|1.6.0|is\_numeric result is now based upon best\_attribute\_type rather than given\_attribute\_type, and the numeric\_xxxx results will appear for those attributes as well; renamed numeric\_correlations result to simply correlations||
|1.6.1|Fix problem where large datasets with implicit numeric conversions ran out of memory during the final phase of profiling|
|1.6.2|Fix issue where a record definition END would appear in the wrong place within BestRecordStructure(); remove BestRecordStructureFromPath() and ProfileFromPath() -- they never worked in all circumstances|
|1.6.3|Fix issue where fields in the NewLayout record definition emitted by BestRecordStructure were out of order|
|1.6.4||

<a name="profile"></a>
### Profile

Documentation as pulled from the beginning of Profile.ecl:

    Profile() is a function macro for profiling all or part of a dataset.
    The output is a dataset containing the following information for each
    profiled attribute:

         attribute               The name of the attribute
         given_attribute_type    The ECL type of the attribute as it was defined
                                 in the input dataset
         best_attribute_type     An ECL data type that both allows all values
                                 in the input dataset and consumes the least
                                 amount of memory
         rec_count               The number of records analyzed in the dataset;
                                 this may be fewer than the total number of
                                 records, if the optional sampleSize argument
                                 was provided with a value less than 100
         fill_count              The number of rec_count records containing
                                 non-nil values; a 'nil value' is an empty
                                 string, a numeric zero, or an empty SET; note
                                 that BOOLEAN attributes are always counted as
                                 filled, regardless of their value; also,
                                 fixed-length DATA attributes (e.g. DATA10) are
                                 also counted as filled, given their typical
                                 function of holding data blobs
         fill_rate               The percentage of rec_count records containing
                                 non-nil values; this is basically
                                 fill_count / rec_count * 100
         cardinality             The number of unique, non-nil values within
                                 the attribute
         cardinality_breakdown   For those attributes with a low number of
                                 unique, non-nil values, show each value and the
                                 number of records containing that value; the
                                 lcbLimit parameter governs what "low number"
                                 means
         modes                   The most common values in the attribute, after
                                 coercing all values to STRING, along with the
                                 number of records in which the values were
                                 found; if no value is repeated more than once
                                 then no mode will be shown; up to five (5)
                                 modes will be shown; note that string values
                                 longer than the maxPatternLen argument will
                                 be truncated
         min_length              For SET datatypes, the fewest number of elements
                                 found in the set; for other data types, the
                                 shortest length of a value when expressed
                                 as a string; null values are ignored
         max_length              For SET datatypes, the largest number of elements
                                 found in the set; for other data types, the
                                 longest length of a value when expressed
                                 as a string; null values are ignored
         ave_length              For SET datatypes, the average number of elements
                                 found in the set; for other data types, the
                                 average length of a value when expressed
         popular_patterns        The most common patterns of values; see below
         rare_patterns           The least common patterns of values; see below
         is_numeric              Boolean indicating if the original attribute
                                 was a numeric scalar or if the best_attribute_type
                                 value was a numeric scaler; if TRUE then the
                                 numeric_xxxx output fields will be
                                 populated with actual values; if this value
                                 is FALSE then all numeric_xxxx output values
                                 should be ignored
         numeric_min             The smallest non-nil value found within the
                                 attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_max             The largest non-nil value found within the
                                 attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_mean            The mean (average) non-nil value found within
                                 the attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_std_dev         The standard deviation of the non-nil values
                                 in the attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_lower_quartile  The value separating the first (bottom) and
                                 second quarters of non-nil values within
                                 the attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_median          The median non-nil value within the attribute
                                 as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_upper_quartile  The value separating the third and fourth
                                 (top) quarters of non-nil values within
                                 the attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         correlations            A child dataset containing correlation values
                                 comparing the current numeric attribute with all
                                 other numeric attributes, listed in descending
                                 correlation value order; the attribute must be
                                 a numeric ECL datatype; non-numeric attributes
                                 will return an empty child dataset; note that
                                 this can be a time-consuming operation,
                                 depending on the number of numeric attributes
                                 in your dataset and the number of rows (if you
                                 have N numeric attributes, then
                                 N * (N - 1) / 2 calculations are performed,
                                 each scanning all data rows)

    Most profile outputs can be disabled.  See the 'features' argument, below.

    Data patterns can give you an idea of what your data looks like when it is
    expressed as a (human-readable) string.  The function converts each
    character of the string into a fixed character palette to produce a "data
    pattern" and then counts the number of unique patterns for that attribute.
    The most- and least-popular patterns from the data will be shown in the
    output, along with the number of times that pattern appears and an example
    (randomly chosen from the actual data).  The character palette used is:

         A   Any uppercase letter
         a   Any lowercase letter
         9   Any numeric digit
         B   A boolean value (true or false)

    All other characters are left as-is in the pattern.

    Function parameters:

    @param   inFile          The dataset to process; this could be a child
                             dataset (e.g. inFile.childDS); REQUIRED
    @param   fieldListStr    A string containing a comma-delimited list of
                             attribute names to process; note that attributes
                             listed here must be scalar datatypes (not child
                             records or child datasets); use an empty string to
                             process all attributes in inFile; OPTIONAL,
                             defaults to an empty string
    @param   maxPatterns     The maximum number of patterns (both popular and
                             rare) to return for each attribute; OPTIONAL,
                             defaults to 100
    @param   maxPatternLen   The maximum length of a pattern; longer patterns
                             are truncated in the output; this value is also
                             used to set the maximum length of the data to
                             consider when finding cardinality and mode values;
                             must be 33 or larger; OPTIONAL, defaults to 100
    @param   features        A comma-delimited string listing the profiling
                             elements to be included in the output; OPTIONAL,
                             defaults to a comma-delimited string containing all
                             of the available keywords:
                                 KEYWORD                 AFFECTED OUTPUT
                                 fill_rate               fill_rate
                                                         fill_count
                                 cardinality             cardinality
                                 cardinality_breakdown   cardinality_breakdown
                                 best_ecl_types          best_attribute_type
                                 modes                   modes
                                 lengths                 min_length
                                                         max_length
                                                         ave_length
                                 patterns                popular_patterns
                                                         rare_patterns
                                 min_max                 numeric_min
                                                         numeric_max
                                 mean                    numeric_mean
                                 std_dev                 numeric_std_dev
                                 quartiles               numeric_lower_quartile
                                                         numeric_median
                                                         numeric_upper_quartile
                                 correlations            correlations
                             To omit the output associated with a single keyword,
                             set this argument to a comma-delimited string
                             containing all other keywords; note that the
                             is_numeric output will appear only if min_max,
                             mean, std_dev, quartiles, or correlations features
                             are active; also note that enabling the
                             cardinality_breakdown feature will also enable
                             the cardinality feature, even if it is not
                             explicitly enabled
    @param   sampleSize      A positive integer representing a percentage of
                             inFile to examine, which is useful when analyzing a
                             very large dataset and only an estimated data
                             profile is sufficient; valid range for this
                             argument is 1-100; values outside of this range
                             will be clamped; OPTIONAL, defaults to 100 (which
                             indicates that the entire dataset will be analyzed)
    @param   lcbLimit        A positive integer (<= 500) indicating the maximum
                             cardinality allowed for an attribute in order to
                             emit a breakdown of the attribute's values; this
                             parameter will be ignored if cardinality_breakdown
                             is not included in the features argument; OPTIONAL,
                             defaults to 64

Here is a very simple example of executing the full data profiling code:

    IMPORT DataPatterns;

    filePath := '~thor::my_sample_data';

    ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);

    profileResults := DataPatterns.Profile(ds);

    OUTPUT(profileResults, ALL, NAMED('profileResults'));

<a name="summary_report_with_graphs"></a>
### Summary Report with Graphs

A report is generated based on the output of `Profile()`. The report is
accessible via a Workunit's *Resources* tab within ECL Watch. For example:

![Screen capture displaying active Resources tab](https://user-images.githubusercontent.com/1891935/57020403-2ac29480-6bf7-11e9-9584-a6fd23a3b4c4.png)

A report can also be viewed directly once a workunit has completed. For example:
https://play.hpccsystems.com:18010/WsWorkunits/res/W20190430-175856/report/res/index.html
(NOTE: This example URL was valid at the time of writing this README entry.)
Simply swap out the host name and WUID in the URL with the WUID containing your
Profile results to view your report.

Every `attribute` in the Profile result is represented by a row of information. 
Each row of information is organized into several columns. Here is a short description 
of each column:

1. Type information, Cardinality Count & Filled Count
2. Min, Avg, Max Length (for string attributes) or Mean, Std. Deviation, Quartiles (for numeric attributes)
3. Quartile bell curve and candlestick
    * only shown for attributes with `is_numeric` === `true`
    * this column is omitted if the above condition fails for all attributes
4. Cardinality Breakdown listed by count descending
    * only shown for attributes with `cardinality_breakdown` content
    * this column is omitted if the above condition fails for all attributes
5. Popular Patterns 
    * only shown for attributes with `popular_patterns` content
    * this column is omitted if the above condition fails for all attributes

This is a screen capture displaying a report row for a string attribute
("Test\_Name") and a numeric attribute ("Test\_Score"):

![Screen capture of two report rows](https://user-images.githubusercontent.com/1891935/56989566-c228d880-6b60-11e9-87a8-c2aa1c76b3d8.png)

<a name="normalizeprofileresults"></a>
### NormalizeProfileResults

The result of a call to `Profile` is a rich dataset.
There are several fields (depending on the features requested) and some
of them can include child datasets embedded for each field from the dataset
being profiled.

In some circumstances, it would be advantageous to save the profile results
in a more normalized format.  For instance, a normalized format would allow
the task of comparing one profile result to another to be much easier.

`NormalizeProfileResults` accepts only one argument:  the dataset representing
the result of a call to either `Profile`.  The result
is a dataset in the following format:

    RECORD
        STRING      attribute;  // Field from profiled dataset
        STRING      key;        // Field from profile results
        STRING      value;      // Value from profile results
    END;

Any child datasets from the profile results (modes, cardinality breakdowns,
text patterns, and correlations) are not copied to the normalized format.

Sample code:

    IMPORT DataPatterns;

    filePath := '~thor::my_sample_data';

    ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);

    profileResults := DataPatterns.Profile(ds);
    
    normalizedResults := DataPatterns.NormalizeProfileResults(profileResults);

    OUTPUT(normalizedResults, ALL, NAMED('normalizedResults'));

profileResults:

|attribute|given\_attribute\_type|rec\_count|fill\_count|fill\_rate|cardinality|
|---|---|---|---|---|---|
|field1|string|1000|1000|100|997|

normalizedResults:

|attribute|key|value|
|---|---|---|
|field1|given\_attribute\_type|string|
|field1|rec\_count|1000|
|field1|fill\_count|1000|
|field1|fill\_rate|100|
|field1|cardinality|997|

<a name="bestrecordstructure"></a>
### BestRecordStructure

This is a function macro that, given a dataset, returns a recordset containing
the "best" record definition for the given dataset.  By default, the entire
dataset will be examined. You can override this behavior by providing a
percentage of the dataset to examine (1-100) as the second argument.  This is
useful if you are checking a very large file and are confident that a sample
will provide correct results.

Sample call:

    IMPORT DataPatterns;

    filePath := '~thor::my_sample_data';

    ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);

    recordDefinition := DataPatterns.BestRecordStructure(ds);

    OUTPUT(recordDefinition, NAMED('recordDefinition'), ALL);

The result will be a recordset containing only a STRING field.  The first
record will always contain 'RECORD' and the last record will always contain
'END;'.  The records in between will contain declarations for the attributes
found within the given dataset.  The entire result can be copied and pasted
into an ECL code module.

Note that, when outputing the result of `BestRecordStructure` to a workunit,
it is a good idea to add an ALL flag to the OUTPUT function.  This ensures that
all attributes will be displayed.  Otherwise, if you have more than 100
attributes in the given dataset, the result will be truncated.

<a name="testing"></a>
### Testing

The data profiling code can be easily tested with the included Tests module.
hthor or ROXIE should be used to execute the tests, simply because Thor takes a
relatively long time to execute them.  Here is how you invoke the tests:

    IMPORT DataPatterns;

    EVALUATE(DataPatterns.Tests);

If the tests pass then the execution will succeed and there will be no output.
These tests may take some time to execute on Thor.  They run much faster on
either hthor or ROXIE, due to the use of small inline datasets.
