pageextension 50101 Priority extends "Sales Lines"
{
    Editable = true;
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