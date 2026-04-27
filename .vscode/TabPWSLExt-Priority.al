tableextension 50103 Priority3 extends "Posted Whse. Shipment Line"
{
    fields
    {
        field(50103; Priority; Boolean)
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