codeunit 50110 "Priority Sales Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibrarySales: Codeunit "Library - Sales";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryERM: Codeunit "Library - ERM";
        LibraryUtility: Codeunit "Library - Utility";
        Assert: Codeunit Assert;

    // -----------------------------------------------------------------------
    // Test: Priority wird vom Verkaufsauftrag in den Warenausgang übertragen
    // und beim Buchen in den Gebuchten Warenausgang übernommen
    // -----------------------------------------------------------------------
    [Test]
    procedure TestPriorityTransferToWarehouseShipmentAndPosting()
    var
        Customer: Record Customer;
        Item: Record Item;
        Location: Record Location;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        PostedWhseShipmentLine: Record "Posted Whse. Shipment Line";
    begin
        // [GIVEN] Stammdaten anlegen
        LibrarySales.CreateCustomer(Customer);
        LibraryInventory.CreateItem(Item);
        CreateLocationWithRequireShipment(Location);

        // [GIVEN] Buchungsmatrix für Lager und Verkauf einrichten
        SetupPostingMatrix(Customer, Item, Location);

        // [GIVEN] Nummernserien für Warenausgänge sicherstellen
        EnsureWarehouseSetupNos();

        // [GIVEN] Bestand am Lagerort buchen (Menge 10)
        CreateAndPostItemJournalLine(Item."No.", Location.Code, 10);

        // [GIVEN] Verkaufsauftrag mit Zeile erstellen, Lagerort und Priority = true setzen
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 1);
        SalesLine.Validate("Location Code", Location.Code);
        SalesLine.Validate(Priority, true);
        SalesLine.Modify(true);

        // [GIVEN] Verkaufsauftrag freigeben (Voraussetzung für Warenausgang)
        LibrarySales.ReleaseSalesDocument(SalesHeader);

        // [WHEN] Warenausgang aus dem Verkaufsauftrag erstellen
        LibraryWarehouse.CreateWhseShipmentFromSO(SalesHeader);

        // [THEN] Warenausgangszeile muss existieren und Priority = true haben
        WarehouseShipmentLine.SetRange("Source Type", Database::"Sales Line");
        WarehouseShipmentLine.SetRange("Source Subtype", SalesHeader."Document Type".AsInteger());
        WarehouseShipmentLine.SetRange("Source No.", SalesHeader."No.");
        Assert.IsTrue(
            WarehouseShipmentLine.FindFirst(),
            'Warenausgangszeile wurde nicht gefunden!');
        Assert.IsTrue(
            WarehouseShipmentLine.Priority,
            'Priority sollte im Warenausgang TRUE sein!');

        // [WHEN] Warenausgang buchen (Liefern)
        WarehouseShipmentHeader.Get(WarehouseShipmentLine."No.");
        LibraryWarehouse.PostWhseShipment(WarehouseShipmentHeader, false);

        // [THEN] Gebuchte Warenausgangszeile muss existieren und Priority = true haben
        PostedWhseShipmentLine.SetRange("Source Type", Database::"Sales Line");
        PostedWhseShipmentLine.SetRange("Source Subtype", SalesHeader."Document Type".AsInteger());
        PostedWhseShipmentLine.SetRange("Source No.", SalesHeader."No.");
        Assert.IsTrue(
            PostedWhseShipmentLine.FindFirst(),
            'Gebuchte Warenausgangszeile nicht gefunden!');
        Assert.IsTrue(
            PostedWhseShipmentLine.Priority,
            'Priority sollte im GEBUCHTEN Warenausgang TRUE sein!');

        // [WHEN] Verkaufsauftrag fakturieren (falls noch vorhanden)
        if SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.") then
            LibrarySales.PostSalesDocument(SalesHeader, false, true);
    end;

    // -----------------------------------------------------------------------
    // Hilfsprozeduren
    // -----------------------------------------------------------------------

    local procedure CreateLocationWithRequireShipment(var Location: Record Location)
    begin
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        Location.Validate("Require Shipment", true);
        Location.Modify(true);
    end;

    local procedure CreateAndPostItemJournalLine(ItemNo: Code[20]; LocationCode: Code[10]; Qty: Decimal)
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalTemplate: Record "Item Journal Template";
    begin
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, ItemJournalTemplate.Type::Item);
        LibraryInventory.SelectItemJournalBatchName(
            ItemJournalBatch, ItemJournalTemplate.Type, ItemJournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
            ItemJournalLine,
            ItemJournalTemplate.Name,
            ItemJournalBatch.Name,
            ItemJournalLine."Entry Type"::"Positive Adjmt.",
            ItemNo,
            Qty);
        ItemJournalLine.Validate("Location Code", LocationCode);
        ItemJournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
    end;

    local procedure EnsureWarehouseSetupNos()
    var
        WhseSetup: Record "Warehouse Setup";
        NoSeriesCode: Code[20];
    begin
        WhseSetup.Get();
        NoSeriesCode := LibraryUtility.GetGlobalNoSeriesCode();
        if WhseSetup."Whse. Ship Nos." = '' then begin
            WhseSetup.Validate("Whse. Ship Nos.", NoSeriesCode);
            WhseSetup.Modify(true);
        end;
        if WhseSetup."Posted Whse. Shipment Nos." = '' then begin
            WhseSetup.Validate("Posted Whse. Shipment Nos.", NoSeriesCode);
            WhseSetup.Modify(true);
        end;
    end;

    local procedure SetupPostingMatrix(var Customer: Record Customer; var Item: Record Item; var Location: Record Location)
    var
        InventoryPostingSetup: Record "Inventory Posting Setup";
        GeneralPostingSetup: Record "General Posting Setup";
    begin
        // Lagerbuchungsmatrix: Lagerort + Lagerbuchungsgruppe des Artikels
        if not InventoryPostingSetup.Get(Location.Code, Item."Inventory Posting Group") then begin
            InventoryPostingSetup.Init();
            InventoryPostingSetup.Validate("Location Code", Location.Code);
            InventoryPostingSetup.Validate("Invt. Posting Group Code", Item."Inventory Posting Group");
            InventoryPostingSetup.Insert(true);
        end;
        if InventoryPostingSetup."Inventory Account" = '' then begin
            InventoryPostingSetup.Validate("Inventory Account", LibraryERM.CreateGLAccountNo());
            InventoryPostingSetup.Modify(true);
        end;

        // Allgemeine Buchungsmatrix: Gen. Bus. Posting Group (Debitor) + Gen. Prod. Posting Group (Artikel)
        if not GeneralPostingSetup.Get(Customer."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group") then
            LibraryERM.CreateGeneralPostingSetup(
                GeneralPostingSetup, Customer."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group");
        if GeneralPostingSetup."Sales Account" = '' then begin
            GeneralPostingSetup.Validate("Sales Account", LibraryERM.CreateGLAccountNo());
            GeneralPostingSetup.Validate("Sales Credit Memo Account", LibraryERM.CreateGLAccountNo());
            GeneralPostingSetup.Validate("COGS Account", LibraryERM.CreateGLAccountNo());
            GeneralPostingSetup.Validate("Inventory Adjmt. Account", LibraryERM.CreateGLAccountNo());
            GeneralPostingSetup.Modify(true);
        end;
    end;
}
