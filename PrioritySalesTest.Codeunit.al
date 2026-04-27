namespace DefaultPublisher.KIInstruktion;

using Microsoft.Sales.Document;
using Microsoft.Sales.Customer;
using Microsoft.Warehouse.Document;
using Microsoft.Warehouse.History;
using Microsoft.Warehouse.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using System.TestLibraries.Utilities;
using Microsoft.Inventory.Journal;

codeunit 50101 "Priority Sales Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibrarySales: Codeunit "Library - Sales";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryAssert: Codeunit "Library Assert";
        LibraryUtility: Codeunit "Library - Utility";

    [Test]
    procedure TestPriorityTransferToWarehouseShipment()
    var
        Customer: Record Customer;
        Item: Record Item;
        Location: Record Location;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        PostedWhseShipmentLine: Record "Posted Whse. Shipment Line";
        WarehouseSetup: Record "Warehouse Setup";
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        NoSeriesCode: Code[20];
    begin
        // 1. Testdaten vorbereiten
        LibrarySales.CreateCustomer(Customer);
        LibraryInventory.CreateItem(Item);

        // Lagerort erstellen mit Warenausgang-Pflicht
        LibraryWarehouse.CreateLocation(Location);
        Location.Validate("Require Shipment", true);
        Location.Modify(true);

        // Bestand auf dem Lagerort buchen (Menge 10)
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::Item);
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, ItemJournalTemplate.Type, ItemJournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJournalLine,
            ItemJournalTemplate.Name,
            ItemJournalBatch.Name,
            ItemJournalLine."Entry Type"::Purchase,
            Item."No.",
            10);
        ItemJournalLine.Validate("Location Code", Location.Code);
        ItemJournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);

        // 2. Nummernserie für Warenausgänge konfigurieren
        NoSeriesCode := LibraryUtility.GetGlobalNoSeriesCode();
        WarehouseSetup.Get();
        WarehouseSetup."Whse. Ship Nos." := NoSeriesCode;
        WarehouseSetup."Posted Whse. Shipment Nos." := NoSeriesCode;
        WarehouseSetup.Modify(true);

        // 3. Verkaufsauftrag mit Priority = true erstellen
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 1);
        SalesLine.Validate("Location Code", Location.Code);
        SalesLine.Validate(Priority, true);
        SalesLine.Modify(true);

        // Verkaufsauftrag freigeben
        LibrarySales.ReleaseSalesDocument(SalesHeader);

        // 4. Warenausgang aus Verkaufsauftrag erstellen
        LibraryWarehouse.CreateWhseShipmentFromSO(SalesHeader);

        WarehouseShipmentHeader.SetRange("Location Code", Location.Code);
        WarehouseShipmentHeader.FindFirst();

        // Priority in der Warenausgangszeile prüfen
        WarehouseShipmentLine.SetRange("No.", WarehouseShipmentHeader."No.");
        WarehouseShipmentLine.SetRange("Source No.", SalesHeader."No.");
        WarehouseShipmentLine.FindFirst();
        LibraryAssert.IsTrue(WarehouseShipmentLine.Priority, 'Priority sollte im Warenausgang TRUE sein!');

        // 5. Warenausgang buchen (Liefern)
        LibraryWarehouse.PostWhseShipment(WarehouseShipmentHeader, false);

        // Priority im gebuchten Warenausgang prüfen
        PostedWhseShipmentLine.SetRange("Source No.", SalesHeader."No.");
        LibraryAssert.IsTrue(PostedWhseShipmentLine.FindFirst(), 'Gebuchte Warenausgangszeile nicht gefunden!');
        LibraryAssert.IsTrue(PostedWhseShipmentLine.Priority, 'Priority sollte im GEBUCHTEN Warenausgang TRUE sein!');

        // 6. Verkaufsauftrag fakturieren
        if SalesHeader.Get(SalesHeader."Document Type"::Order, SalesHeader."No.") then
            LibrarySales.PostSalesDocument(SalesHeader, false, true);
    end;
}
