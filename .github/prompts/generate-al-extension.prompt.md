---
description: "Generate AL tableextension and pageextension objects for a given base table/page"
name: "Generate AL Extension Objects"
argument-hint: "Base table name, e.g. 'Sales Line'"
agent: "agent"
tools: [codebase]
---

Generate a pair of AL extension objects — a **tableextension** and a matching **pageextension** — based on the user's input.

## Instructions

1. Ask the user (or read from the argument) for:
   - The **base table name** to extend (e.g. `Sales Line`)
   - The **matching page name** to extend (e.g. `Sales Lines`)
   - The **new field name(s)** and their **data type(s)** to add
   - The **object ID range** to use (default: start at 50100 if not specified)

2. Generate a `tableextension` file following this pattern:

```al
tableextension <ID> <FieldName> extends "<Base Table>"
{
    fields
    {
        field(<ID>; <FieldName>; <DataType>)
        {
            Caption = '<FieldName>';
            DataClassification = CustomerContent;
        }
    }
}
```

3. Generate a `pageextension` file following this pattern:

```al
pageextension <ID+1> <FieldName> extends "<Base Page>"
{
    layout
    {
        addlast(General)
        {
            field(<FieldName>; Rec.<FieldName>)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies <FieldName>.';
            }
        }
    }
}
```

4. Use the naming convention from the workspace:
   - Table extension file: `Tab<BaseName>Ext-<ID>.<FieldName>.al`
   - Page extension file: `Pag<BaseName>Ext-<ID+1>_<FieldName>.al`

5. Write the generated files directly into the active workspace folder.

## Example

**Input**: Base table `Sales Line`, page `Sales Lines`, field `Priority` (Boolean), ID 50100

**Output**:
- `TabSalesLineExt-50100.Priority.al` — tableextension 50100 with field Priority : Boolean
- `PagSalesLineExt-50101_Priority.al` — pageextension 50101 showing the Priority field on the Sales Lines page
