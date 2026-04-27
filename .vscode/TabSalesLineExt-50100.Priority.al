tableextension 50100 Priority extends "Sales Line"
{
    fields
    {
        field(50100; Priority; Boolean)
        {
            Caption = 'Priority';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        // Add changes to keys here
    }

    fieldgroups
    {
        // Add changes to field groups here
    }

    var
        myInt: Integer;
}