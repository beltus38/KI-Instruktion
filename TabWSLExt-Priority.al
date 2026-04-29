tableextension 50102 Priority2 extends "Warehouse Shipment Line"
{
    fields
    {
        field(50102; Priority; Boolean)
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