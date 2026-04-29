codeunit 50102 MyEventSubscriber
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Create Source Document", OnBeforeWhseShptLineInsert, '', false, false)]
    procedure OnBeforeWhseShptLineInsert(var WarehouseShipmentLine: Record "Warehouse Shipment Line")
    var
        SalesLine: record "Sales Line";
    begin
        if WarehouseShipmentLine."Source Type" = Database::"Sales Line" then begin
            if SalesLine.Get(WarehouseShipmentLine."Source Subtype", WarehouseShipmentLine."Source No.", WarehouseShipmentLine."Source Line No.") then begin
                // Jetzt haben wir die richtige Zeile und können den Wert kopieren
                WarehouseShipmentLine.Priority := SalesLine.Priority;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Post Shipment", OnCreatePostedShptLineOnBeforePostedWhseShptLineInsert, '', false, false)]
    procedure OnCreatePostedShptLineOnBeforePostedWhseShptLineInsert(var PostedWhseShptLine: Record "Posted Whse. Shipment Line"; WhseShptLine: Record "Warehouse Shipment Line")

    var

    begin
        PostedWhseShptLine.Priority := WhseShptLine.Priority;
    end;

}