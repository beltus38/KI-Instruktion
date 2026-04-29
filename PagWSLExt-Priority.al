pageextension 50102 Priority2 extends "Warehouse Shipment List"
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