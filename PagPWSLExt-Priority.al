pageextension 50103 Priority3 extends "Posted Whse. Shipment List"
{
    Editable = false;
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addlast(Processing)
        {
            action(Priority)
            {
                Caption = 'Priority';
                ApplicationArea = all;

            }
        }
    }


}