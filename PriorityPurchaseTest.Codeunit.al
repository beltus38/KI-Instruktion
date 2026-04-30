codeunit 50111 "Priority Purchase Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryERM: Codeunit "Library - ERM";
        LibraryUtility: Codeunit "Library - Utility";
        Assert: Codeunit Assert;

    // -----------------------------------------------------------------------
    // Test: Einkaufsbestellung anlegen, buchen (Liefern + Fakturieren)
    // und den gebuchten Wareneingang überprüfen
    // -----------------------------------------------------------------------
    [Test]
    procedure TestPurchaseOrderReceiveAndInvoice()
    var
        Vendor: Record Vendor;
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        PurchInvHeader: Record "Purch. Inv. Header";
    begin
        // [GIVEN] Kreditor anlegen
        LibraryPurchase.CreateVendor(Vendor);

        // [GIVEN] Artikel anlegen
        LibraryInventory.CreateItem(Item);

        // [GIVEN] Buchungsmatrix für Einkauf einrichten
        SetupPurchasePostingMatrix(Vendor, Item);

        // [GIVEN] Einkaufsbestellung anlegen
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        PurchaseHeader.Validate("Vendor Invoice No.", LibraryUtility.GenerateRandomCode(PurchaseHeader.FieldNo("Vendor Invoice No."), Database::"Purchase Header"));
        PurchaseHeader.Modify(true);

        // [GIVEN] Einkaufszeile anlegen (Menge: 10, Einkaufspreis: 100)
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        // [WHEN] Einkaufsbestellung buchen (Liefern und Fakturieren)
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, true);

        // [THEN] Gebuchter Wareneingang muss existieren
        PurchRcptHeader.SetRange("Buy-from Vendor No.", Vendor."No.");
        Assert.IsTrue(
            PurchRcptHeader.FindFirst(),
            'Gebuchter Wareneingang wurde nicht gefunden!');

        // [THEN] Gebuchte Einkaufsrechnung muss existieren
        PurchInvHeader.SetRange("Buy-from Vendor No.", Vendor."No.");
        Assert.IsTrue(
            PurchInvHeader.FindFirst(),
            'Gebuchte Einkaufsrechnung wurde nicht gefunden!');

        // [THEN] Menge im gebuchten Wareneingang prüfen
        VerifyPurchaseReceiptQty(PurchRcptHeader."No.", Item."No.", 10);
    end;

    // -----------------------------------------------------------------------
    // Test: Einkaufsbestellung mit Lagerort und Wareneingang (Warehouse Receipt)
    // -----------------------------------------------------------------------
    [Test]
    procedure TestPurchaseOrderWithWarehouseReceipt()
    var
        Vendor: Record Vendor;
        Item: Record Item;
        Location: Record Location;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        WarehouseReceiptHeader: Record "Warehouse Receipt Header";
        WarehouseReceiptLine: Record "Warehouse Receipt Line";
        PostedWhseReceiptLine: Record "Posted Whse. Receipt Line";
    begin
        // [GIVEN] Stammdaten anlegen
        LibraryPurchase.CreateVendor(Vendor);
        LibraryInventory.CreateItem(Item);
        CreateLocationWithRequireReceipt(Location);

        // [GIVEN] Buchungsmatrizen einrichten
        SetupPurchasePostingMatrix(Vendor, Item);
        SetupInventoryPostingSetupForLocation(Item, Location);

        // [GIVEN] Nummerserien für Wareneingänge sicherstellen
        EnsureWarehouseSetupNos();

        // [GIVEN] Einkaufsbestellung anlegen
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        PurchaseHeader.Validate("Vendor Invoice No.", LibraryUtility.GenerateRandomCode(PurchaseHeader.FieldNo("Vendor Invoice No."), Database::"Purchase Header"));
        PurchaseHeader.Modify(true);

        // [GIVEN] Einkaufszeile anlegen (Menge: 5, Lagerort setzen)
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 5);
        PurchaseLine.Validate("Location Code", Location.Code);
        PurchaseLine.Validate("Direct Unit Cost", 50);
        PurchaseLine.Modify(true);

        // [GIVEN] Einkaufsbestellung freigeben (Voraussetzung für Wareneingang)
        LibraryPurchase.ReleasePurchaseDocument(PurchaseHeader);

        // [WHEN] Wareneingang aus der Einkaufsbestellung erstellen
        LibraryWarehouse.CreateWhseReceiptFromPO(PurchaseHeader);

        // [THEN] Wareneingangszeile muss existieren
        WarehouseReceiptLine.SetRange("Source Type", Database::"Purchase Line");
        WarehouseReceiptLine.SetRange("Source Subtype", PurchaseHeader."Document Type".AsInteger());
        WarehouseReceiptLine.SetRange("Source No.", PurchaseHeader."No.");
        Assert.IsTrue(
            WarehouseReceiptLine.FindFirst(),
            'Wareneingangszeile wurde nicht gefunden!');

        // [THEN] Menge in der Wareneingangszeile prüfen
        Assert.AreEqual(
            5,
            WarehouseReceiptLine."Qty. to Receive",
            'Menge in der Wareneingangszeile ist falsch!');

        // [WHEN] Wareneingang buchen
        WarehouseReceiptHeader.Get(WarehouseReceiptLine."No.");
        LibraryWarehouse.PostWhseReceipt(WarehouseReceiptHeader);

        // [THEN] Gebuchte Wareneingangszeile muss existieren
        PostedWhseReceiptLine.SetRange("Source Type", Database::"Purchase Line");
        PostedWhseReceiptLine.SetRange("Source Subtype", PurchaseHeader."Document Type".AsInteger());
        PostedWhseReceiptLine.SetRange("Source No.", PurchaseHeader."No.");
        Assert.IsTrue(
            PostedWhseReceiptLine.FindFirst(),
            'Gebuchte Wareneingangszeile nicht gefunden!');

        // [THEN] Gebuchte Menge prüfen
        Assert.AreEqual(
            5,
            PostedWhseReceiptLine."Quantity",
            'Gebuchte Menge in der Wareneingangszeile ist falsch!');
    end;

    // -----------------------------------------------------------------------
    // Hilfsprozeduren
    // -----------------------------------------------------------------------

    local procedure CreateLocationWithRequireReceipt(var Location: Record Location)
    begin
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        Location.Validate("Require Receive", true);
        Location.Modify(true);
    end;

    local procedure SetupPurchasePostingMatrix(var Vendor: Record Vendor; var Item: Record Item)
    var
        GeneralPostingSetup: Record "General Posting Setup";
    begin
        // Allgemeine Buchungsmatrix: Gen. Bus. Posting Group (Kreditor) + Gen. Prod. Posting Group (Artikel)
        if not GeneralPostingSetup.Get(Vendor."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group") then
            LibraryERM.CreateGeneralPostingSetup(
                GeneralPostingSetup, Vendor."Gen. Bus. Posting Group", Item."Gen. Prod. Posting Group");
        if GeneralPostingSetup."Purch. Account" = '' then begin
            GeneralPostingSetup.Validate("Purch. Account", LibraryERM.CreateGLAccountNo());
            GeneralPostingSetup.Validate("Purch. Credit Memo Account", LibraryERM.CreateGLAccountNo());
            GeneralPostingSetup.Validate("COGS Account", LibraryERM.CreateGLAccountNo());
            GeneralPostingSetup.Validate("Inventory Adjmt. Account", LibraryERM.CreateGLAccountNo());
            GeneralPostingSetup.Modify(true);
        end;
    end;

    local procedure SetupInventoryPostingSetupForLocation(var Item: Record Item; var Location: Record Location)
    var
        InventoryPostingSetup: Record "Inventory Posting Setup";
    begin
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
    end;

    local procedure EnsureWarehouseSetupNos()
    var
        WhseSetup: Record "Warehouse Setup";
        NoSeriesCode: Code[20];
    begin
        WhseSetup.Get();
        NoSeriesCode := LibraryUtility.GetGlobalNoSeriesCode();
        if WhseSetup."Whse. Receipt Nos." = '' then begin
            WhseSetup.Validate("Whse. Receipt Nos.", NoSeriesCode);
            WhseSetup.Modify(true);
        end;
        if WhseSetup."Posted Whse. Receipt Nos." = '' then begin
            WhseSetup.Validate("Posted Whse. Receipt Nos.", NoSeriesCode);
            WhseSetup.Modify(true);
        end;
    end;

    local procedure VerifyPurchaseReceiptQty(RcptNo: Code[20]; ItemNo: Code[20]; ExpectedQty: Decimal)
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
    begin
        PurchRcptLine.SetRange("Document No.", RcptNo);
        PurchRcptLine.SetRange("No.", ItemNo);
        Assert.IsTrue(
            PurchRcptLine.FindFirst(),
            'Gebuchte Wareneingangszeile für Artikel nicht gefunden!');
        Assert.AreEqual(
            ExpectedQty,
            PurchRcptLine.Quantity,
            'Menge im gebuchten Wareneingang stimmt nicht!');
    end;
}
