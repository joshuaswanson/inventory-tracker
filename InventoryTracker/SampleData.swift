import Foundation
import SwiftData

struct SampleData {
    static func populate(modelContext: ModelContext) {
        // MARK: - Vendors
        // Mix of suppliers - some have best prices, some never do

        let henrySchein = Vendor(
            name: "Henry Schein",
            contactName: "Mike Thompson",
            phone: "(800) 472-4346",
            email: "orders@henryschein.com",
            address: "135 Duryea Rd, Melville, NY 11747",
            notes: "Primary supplier, good bulk discounts"
        )

        let patterson = Vendor(
            name: "Patterson Dental",
            contactName: "Sarah Chen",
            phone: "(800) 328-5536",
            email: "support@pattersondental.com",
            address: "1031 Mendota Heights Rd, St Paul, MN 55120",
            notes: "Fast shipping, equipment specialist"
        )

        let benco = Vendor(
            name: "Benco Dental",
            contactName: "James Wilson",
            phone: "(800) 462-3626",
            email: "customerservice@benco.com",
            address: "295 CenterPoint Blvd, Pittston, PA 18640",
            notes: "Good prices on consumables"
        )

        let darby = Vendor(
            name: "Darby Dental",
            contactName: "Lisa Martinez",
            phone: "(800) 645-2310",
            email: "sales@darbydental.com",
            address: "300 Jericho Quadrangle, Jericho, NY 11753",
            notes: "Competitive pricing"
        )

        // Vendors that NEVER have the best price
        let localSupply = Vendor(
            name: "Metro Dental Supply",
            contactName: "Bob Reynolds",
            phone: "(555) 234-5678",
            email: "bob@metrodental.local",
            address: "123 Main St, Suite 100",
            notes: "Local supplier, same-day delivery available but higher prices"
        )

        let emergencyDental = Vendor(
            name: "Emergency Dental Express",
            contactName: "Quick Response Team",
            phone: "(800) 911-DENT",
            email: "rush@emergencydental.com",
            address: "24/7 Distribution Center",
            notes: "24-hour delivery, premium pricing for rush orders"
        )

        let premiumSupplies = Vendor(
            name: "Premium Dental Supplies",
            contactName: "Victoria Sterling",
            phone: "(888) 555-1234",
            email: "concierge@premiumdental.com",
            address: "500 Luxury Lane, Beverly Hills, CA 90210",
            notes: "White-glove service, highest prices but excellent quality"
        )

        let budgetDental = Vendor(
            name: "Budget Dental Warehouse",
            contactName: "Customer Service",
            phone: "(800) 555-SAVE",
            email: "orders@budgetdental.com",
            address: "1000 Industrial Pkwy",
            notes: "Bulk orders only, slow shipping, prices not actually that great"
        )

        let vendors = [henrySchein, patterson, benco, darby, localSupply, emergencyDental, premiumSupplies, budgetDental]
        vendors.forEach { modelContext.insert($0) }

        // MARK: - Items

        let nitrileGlovesS = Item(
            name: "Nitrile Gloves - Small",
            unitOfMeasure: .box,
            reorderLevel: 10,
            isPerishable: false,
            notes: "Blue, powder-free, 100/box"
        )

        let nitrileGlovesM = Item(
            name: "Nitrile Gloves - Medium",
            unitOfMeasure: .box,
            reorderLevel: 15,
            isPerishable: false,
            notes: "Blue, powder-free, 100/box"
        )

        let nitrileGlovesL = Item(
            name: "Nitrile Gloves - Large",
            unitOfMeasure: .box,
            reorderLevel: 10,
            isPerishable: false,
            notes: "Blue, powder-free, 100/box"
        )

        let faceMasks = Item(
            name: "Level 3 Face Masks",
            unitOfMeasure: .box,
            reorderLevel: 5,
            isPerishable: false,
            notes: "ASTM Level 3, 50/box"
        )

        let dentalBibs = Item(
            name: "Dental Bibs",
            unitOfMeasure: .caseUnit,
            reorderLevel: 3,
            isPerishable: false,
            notes: "Blue, 2-ply, 500/case"
        )

        let sterilizationPouches = Item(
            name: "Sterilization Pouches 3.5x10",
            unitOfMeasure: .box,
            reorderLevel: 8,
            isPerishable: false,
            notes: "Self-sealing, 200/box"
        )

        let compositA2 = Item(
            name: "Composite Resin - A2",
            unitOfMeasure: .each,
            reorderLevel: 5,
            isPerishable: true,
            notes: "4g syringe, universal shade"
        )

        let compositA3 = Item(
            name: "Composite Resin - A3",
            unitOfMeasure: .each,
            reorderLevel: 4,
            isPerishable: true,
            notes: "4g syringe"
        )

        let bondingAgent = Item(
            name: "Universal Bonding Agent",
            unitOfMeasure: .bottle,
            reorderLevel: 3,
            isPerishable: true,
            notes: "5ml bottle, light-cure"
        )

        let etchGel = Item(
            name: "Phosphoric Acid Etch Gel 37%",
            unitOfMeasure: .each,
            reorderLevel: 6,
            isPerishable: true,
            notes: "3ml syringe with tips"
        )

        let lidocaine = Item(
            name: "Lidocaine 2% w/ Epi 1:100,000",
            unitOfMeasure: .box,
            reorderLevel: 4,
            isPerishable: true,
            notes: "1.7ml cartridges, 50/box"
        )

        let dentalNeedles = Item(
            name: "Dental Needles 27G Short",
            unitOfMeasure: .box,
            reorderLevel: 5,
            isPerishable: false,
            notes: "100/box"
        )

        let cottonRolls = Item(
            name: "Cotton Rolls #2 Medium",
            unitOfMeasure: .bag,
            reorderLevel: 4,
            isPerishable: false,
            notes: "2000/bag"
        )

        let gauze = Item(
            name: "Gauze Sponges 2x2",
            unitOfMeasure: .pack,
            reorderLevel: 6,
            isPerishable: false,
            notes: "Non-sterile, 200/pack"
        )

        let prophyPaste = Item(
            name: "Prophy Paste - Medium Grit",
            unitOfMeasure: .box,
            reorderLevel: 3,
            isPerishable: true,
            notes: "Mint flavor, 200 cups/box"
        )

        let fluorideVarnish = Item(
            name: "Fluoride Varnish 5%",
            unitOfMeasure: .box,
            reorderLevel: 2,
            isPerishable: true,
            notes: "Unit doses, 50/box, bubblegum flavor"
        )

        let alginate = Item(
            name: "Alginate Impression Material",
            unitOfMeasure: .pound,
            reorderLevel: 5,
            isPerishable: true,
            notes: "Fast set, 1lb canister"
        )

        let pvsSyringe = Item(
            name: "PVS Impression Material - Light Body",
            unitOfMeasure: .each,
            reorderLevel: 4,
            isPerishable: true,
            notes: "50ml cartridge"
        )

        let tempCrown = Item(
            name: "Temporary Crown Material",
            unitOfMeasure: .each,
            reorderLevel: 3,
            isPerishable: true,
            notes: "A2 shade, 76g cartridge"
        )

        let suctionTips = Item(
            name: "Saliva Ejectors",
            unitOfMeasure: .bag,
            reorderLevel: 4,
            isPerishable: false,
            notes: "White, 100/bag"
        )

        let hveSuction = Item(
            name: "HVE Suction Tips",
            unitOfMeasure: .bag,
            reorderLevel: 3,
            isPerishable: false,
            notes: "Vented, 100/bag"
        )

        let airWaterTips = Item(
            name: "Air/Water Syringe Tips",
            unitOfMeasure: .bag,
            reorderLevel: 4,
            isPerishable: false,
            notes: "Disposable, 250/bag"
        )

        let disinfectantWipes = Item(
            name: "Surface Disinfectant Wipes",
            unitOfMeasure: .each,
            reorderLevel: 6,
            isPerishable: true,
            notes: "160 count canister, EPA registered"
        )

        let barrierFilm = Item(
            name: "Barrier Film",
            unitOfMeasure: .roll,
            reorderLevel: 8,
            isPerishable: false,
            notes: "4x6 inch, 1200/roll, blue"
        )

        let items = [
            nitrileGlovesS, nitrileGlovesM, nitrileGlovesL, faceMasks, dentalBibs,
            sterilizationPouches, compositA2, compositA3, bondingAgent, etchGel,
            lidocaine, dentalNeedles, cottonRolls, gauze, prophyPaste,
            fluorideVarnish, alginate, pvsSyringe, tempCrown, suctionTips,
            hveSuction, airWaterTips, disinfectantWipes, barrierFilm
        ]
        items.forEach { modelContext.insert($0) }

        // MARK: - Helper for dates
        func daysAgo(_ days: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        }

        func daysFromNow(_ days: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        }

        // MARK: - Purchases
        // Best prices: Henry Schein, Patterson, Benco, Darby each have some
        // NO best prices: localSupply, emergencyDental, premiumSupplies, budgetDental

        // Nitrile Gloves Medium - HIGH STOCK, reorder=15
        // Purchased: 80, will use ~30, stock ~50 (well above 15)
        // BEST: Henry Schein at $6.50
        modelContext.insert(Purchase(item: nitrileGlovesM, vendor: henrySchein, date: daysAgo(60), quantity: 30, pricePerUnit: 6.50, lotNumber: "HS-2024-001"))
        modelContext.insert(Purchase(item: nitrileGlovesM, vendor: patterson, date: daysAgo(45), quantity: 20, pricePerUnit: 7.25, lotNumber: "PT-2024-102"))
        modelContext.insert(Purchase(item: nitrileGlovesM, vendor: localSupply, date: daysAgo(30), quantity: 15, pricePerUnit: 8.99, lotNumber: "MDS-445"))
        modelContext.insert(Purchase(item: nitrileGlovesM, vendor: emergencyDental, date: daysAgo(10), quantity: 15, pricePerUnit: 12.00, lotNumber: "ED-001"))

        // Nitrile Gloves Small - GOOD STOCK, reorder=10
        // Purchased: 50, will use ~20, stock ~30
        // BEST: Darby at $6.25
        modelContext.insert(Purchase(item: nitrileGlovesS, vendor: darby, date: daysAgo(60), quantity: 25, pricePerUnit: 6.25, lotNumber: "DD-9981"))
        modelContext.insert(Purchase(item: nitrileGlovesS, vendor: henrySchein, date: daysAgo(30), quantity: 15, pricePerUnit: 6.50, lotNumber: "HS-2024-002"))
        modelContext.insert(Purchase(item: nitrileGlovesS, vendor: premiumSupplies, date: daysAgo(15), quantity: 10, pricePerUnit: 9.99, lotNumber: "PS-GL-001"))

        // Nitrile Gloves Large - LOW STOCK (one of few), reorder=10
        // Purchased: 20, will use ~15, stock ~5 (below 10)
        // BEST: Patterson at $6.40
        modelContext.insert(Purchase(item: nitrileGlovesL, vendor: patterson, date: daysAgo(90), quantity: 12, pricePerUnit: 6.40, lotNumber: "PT-2024-055"))
        modelContext.insert(Purchase(item: nitrileGlovesL, vendor: budgetDental, date: daysAgo(45), quantity: 8, pricePerUnit: 7.50, lotNumber: "BD-GL-001"))

        // Face Masks - GOOD STOCK, reorder=5
        // Purchased: 25, will use ~8, stock ~17
        // BEST: Benco at $12.50
        modelContext.insert(Purchase(item: faceMasks, vendor: benco, date: daysAgo(45), quantity: 15, pricePerUnit: 12.50, lotNumber: "BC-FM-901"))
        modelContext.insert(Purchase(item: faceMasks, vendor: localSupply, date: daysAgo(20), quantity: 10, pricePerUnit: 16.99, lotNumber: "MDS-FM-01"))

        // Dental Bibs - GOOD STOCK, reorder=3
        // Purchased: 12, will use ~4, stock ~8
        // BEST: Henry Schein at $45.00
        modelContext.insert(Purchase(item: dentalBibs, vendor: henrySchein, date: daysAgo(90), quantity: 6, pricePerUnit: 45.00, lotNumber: "HS-DB-221"))
        modelContext.insert(Purchase(item: dentalBibs, vendor: patterson, date: daysAgo(45), quantity: 4, pricePerUnit: 48.50, lotNumber: "PT-DB-445"))
        modelContext.insert(Purchase(item: dentalBibs, vendor: emergencyDental, date: daysAgo(15), quantity: 2, pricePerUnit: 65.00, lotNumber: "ED-DB-001"))

        // Sterilization Pouches - GOOD STOCK, reorder=8
        // Purchased: 30, will use ~10, stock ~20
        // BEST: Benco at $22.00
        modelContext.insert(Purchase(item: sterilizationPouches, vendor: benco, date: daysAgo(60), quantity: 18, pricePerUnit: 22.00, lotNumber: "BC-SP-901"))
        modelContext.insert(Purchase(item: sterilizationPouches, vendor: premiumSupplies, date: daysAgo(30), quantity: 12, pricePerUnit: 28.00, lotNumber: "PS-SP-001"))

        // Composite A2 - GOOD STOCK with EXPIRING items, reorder=5
        // Purchased: 18, will use ~6, stock ~12
        // BEST: Patterson at $125.00
        modelContext.insert(Purchase(item: compositA2, vendor: patterson, date: daysAgo(180), quantity: 8, pricePerUnit: 125.00, lotNumber: "PT-CA2-001", expirationDate: daysFromNow(5))) // EXPIRING SOON!
        modelContext.insert(Purchase(item: compositA2, vendor: henrySchein, date: daysAgo(60), quantity: 6, pricePerUnit: 132.00, lotNumber: "HS-CA2-445", expirationDate: daysFromNow(180)))
        modelContext.insert(Purchase(item: compositA2, vendor: localSupply, date: daysAgo(20), quantity: 4, pricePerUnit: 145.00, lotNumber: "MDS-CA2-01", expirationDate: daysFromNow(365)))

        // Composite A3 - GOOD STOCK, reorder=4
        // Purchased: 14, will use ~4, stock ~10
        // BEST: Benco at $122.00
        modelContext.insert(Purchase(item: compositA3, vendor: benco, date: daysAgo(120), quantity: 8, pricePerUnit: 122.00, lotNumber: "BC-CA3-088", expirationDate: daysFromNow(20))) // WARNING
        modelContext.insert(Purchase(item: compositA3, vendor: budgetDental, date: daysAgo(45), quantity: 6, pricePerUnit: 135.00, lotNumber: "BD-CA3-001", expirationDate: daysFromNow(240)))

        // Bonding Agent - LOW STOCK with EXPIRING, reorder=3
        // Purchased: 6, will use ~4, stock ~2 (below 3)
        // BEST: Darby at $89.00
        modelContext.insert(Purchase(item: bondingAgent, vendor: darby, date: daysAgo(150), quantity: 4, pricePerUnit: 89.00, lotNumber: "DD-BA-001", expirationDate: daysFromNow(3))) // CRITICAL!
        modelContext.insert(Purchase(item: bondingAgent, vendor: emergencyDental, date: daysAgo(30), quantity: 2, pricePerUnit: 115.00, lotNumber: "ED-BA-001", expirationDate: daysFromNow(120)))

        // Etch Gel - GOOD STOCK, reorder=6
        // Purchased: 25, will use ~8, stock ~17
        // BEST: Henry Schein at $8.50
        modelContext.insert(Purchase(item: etchGel, vendor: henrySchein, date: daysAgo(90), quantity: 15, pricePerUnit: 8.50, lotNumber: "HS-EG-901", expirationDate: daysFromNow(90)))
        modelContext.insert(Purchase(item: etchGel, vendor: premiumSupplies, date: daysAgo(30), quantity: 10, pricePerUnit: 12.00, lotNumber: "PS-EG-001", expirationDate: daysFromNow(180)))

        // Lidocaine - GOOD STOCK with some EXPIRING, reorder=4
        // Purchased: 15, will use ~5, stock ~10
        // BEST: Patterson at $42.00
        modelContext.insert(Purchase(item: lidocaine, vendor: patterson, date: daysAgo(150), quantity: 8, pricePerUnit: 42.00, lotNumber: "PT-LID-001", expirationDate: daysFromNow(7))) // CRITICAL!
        modelContext.insert(Purchase(item: lidocaine, vendor: localSupply, date: daysAgo(45), quantity: 4, pricePerUnit: 52.00, lotNumber: "MDS-LID-01", expirationDate: daysFromNow(365)))
        modelContext.insert(Purchase(item: lidocaine, vendor: henrySchein, date: daysAgo(15), quantity: 3, pricePerUnit: 45.00, lotNumber: "HS-LID-556", expirationDate: daysFromNow(400)))

        // Dental Needles - GOOD STOCK, reorder=5
        // Purchased: 22, will use ~6, stock ~16
        // BEST: Benco at $15.00
        modelContext.insert(Purchase(item: dentalNeedles, vendor: benco, date: daysAgo(75), quantity: 12, pricePerUnit: 15.00, lotNumber: "BC-DN-445"))
        modelContext.insert(Purchase(item: dentalNeedles, vendor: budgetDental, date: daysAgo(30), quantity: 10, pricePerUnit: 18.50, lotNumber: "BD-DN-001"))

        // Cotton Rolls - GOOD STOCK, reorder=4
        // Purchased: 15, will use ~5, stock ~10
        // BEST: Darby at $18.00
        modelContext.insert(Purchase(item: cottonRolls, vendor: darby, date: daysAgo(60), quantity: 10, pricePerUnit: 18.00, lotNumber: "DD-CR-001"))
        modelContext.insert(Purchase(item: cottonRolls, vendor: premiumSupplies, date: daysAgo(20), quantity: 5, pricePerUnit: 25.00, lotNumber: "PS-CR-001"))

        // Gauze - GOOD STOCK, reorder=6
        // Purchased: 20, will use ~5, stock ~15
        // BEST: Darby at $8.25
        modelContext.insert(Purchase(item: gauze, vendor: darby, date: daysAgo(45), quantity: 12, pricePerUnit: 8.25, lotNumber: "DD-GZ-901"))
        modelContext.insert(Purchase(item: gauze, vendor: localSupply, date: daysAgo(15), quantity: 8, pricePerUnit: 11.00, lotNumber: "MDS-GZ-01"))

        // Prophy Paste - GOOD STOCK with EXPIRING, reorder=3
        // Purchased: 10, will use ~3, stock ~7
        // BEST: Benco at $28.00
        modelContext.insert(Purchase(item: prophyPaste, vendor: benco, date: daysAgo(100), quantity: 6, pricePerUnit: 28.00, lotNumber: "BC-PP-667", expirationDate: daysFromNow(25))) // WARNING
        modelContext.insert(Purchase(item: prophyPaste, vendor: emergencyDental, date: daysAgo(30), quantity: 4, pricePerUnit: 38.00, lotNumber: "ED-PP-001", expirationDate: daysFromNow(180)))

        // Fluoride Varnish - LOW STOCK with EXPIRING, reorder=2
        // Purchased: 5, will use ~3, stock ~2 (at reorder level)
        // BEST: Patterson at $75.00
        modelContext.insert(Purchase(item: fluorideVarnish, vendor: patterson, date: daysAgo(90), quantity: 3, pricePerUnit: 75.00, lotNumber: "PT-FV-001", expirationDate: daysFromNow(14))) // WARNING
        modelContext.insert(Purchase(item: fluorideVarnish, vendor: premiumSupplies, date: daysAgo(30), quantity: 2, pricePerUnit: 95.00, lotNumber: "PS-FV-001", expirationDate: daysFromNow(300)))

        // Alginate - GOOD STOCK, reorder=5
        // Purchased: 16, will use ~4, stock ~12
        // BEST: Henry Schein at $24.00
        modelContext.insert(Purchase(item: alginate, vendor: henrySchein, date: daysAgo(75), quantity: 10, pricePerUnit: 24.00, lotNumber: "HS-ALG-445", expirationDate: daysFromNow(60)))
        modelContext.insert(Purchase(item: alginate, vendor: budgetDental, date: daysAgo(30), quantity: 6, pricePerUnit: 29.00, lotNumber: "BD-ALG-001", expirationDate: daysFromNow(180)))

        // PVS Material - GOOD STOCK, reorder=4
        // Purchased: 18, will use ~5, stock ~13
        // BEST: Darby at $35.00
        modelContext.insert(Purchase(item: pvsSyringe, vendor: darby, date: daysAgo(60), quantity: 10, pricePerUnit: 35.00, lotNumber: "DD-PVS-901", expirationDate: daysFromNow(365)))
        modelContext.insert(Purchase(item: pvsSyringe, vendor: localSupply, date: daysAgo(25), quantity: 8, pricePerUnit: 42.00, lotNumber: "MDS-PVS-01", expirationDate: daysFromNow(400)))

        // Temp Crown Material - GOOD STOCK, reorder=3
        // Purchased: 10, will use ~3, stock ~7
        // BEST: Henry Schein at $85.00
        modelContext.insert(Purchase(item: tempCrown, vendor: henrySchein, date: daysAgo(90), quantity: 6, pricePerUnit: 85.00, lotNumber: "HS-TC-112", expirationDate: daysFromNow(90)))
        modelContext.insert(Purchase(item: tempCrown, vendor: emergencyDental, date: daysAgo(30), quantity: 4, pricePerUnit: 110.00, lotNumber: "ED-TC-001", expirationDate: daysFromNow(180)))

        // Saliva Ejectors - HIGH STOCK, reorder=4
        // Purchased: 25, will use ~8, stock ~17
        // BEST: Benco at $5.25
        modelContext.insert(Purchase(item: suctionTips, vendor: benco, date: daysAgo(45), quantity: 15, pricePerUnit: 5.25, lotNumber: "BC-SE-002"))
        modelContext.insert(Purchase(item: suctionTips, vendor: premiumSupplies, date: daysAgo(15), quantity: 10, pricePerUnit: 8.00, lotNumber: "PS-SE-001"))

        // HVE Tips - GOOD STOCK, reorder=3
        // Purchased: 14, will use ~5, stock ~9
        // BEST: Benco at $12.00
        modelContext.insert(Purchase(item: hveSuction, vendor: benco, date: daysAgo(60), quantity: 8, pricePerUnit: 12.00, lotNumber: "BC-HVE-334"))
        modelContext.insert(Purchase(item: hveSuction, vendor: budgetDental, date: daysAgo(20), quantity: 6, pricePerUnit: 16.00, lotNumber: "BD-HVE-001"))

        // Air/Water Tips - GOOD STOCK, reorder=4
        // Purchased: 18, will use ~6, stock ~12
        // BEST: Patterson at $15.00
        modelContext.insert(Purchase(item: airWaterTips, vendor: patterson, date: daysAgo(75), quantity: 10, pricePerUnit: 15.00, lotNumber: "PT-AW-667"))
        modelContext.insert(Purchase(item: airWaterTips, vendor: localSupply, date: daysAgo(30), quantity: 8, pricePerUnit: 20.00, lotNumber: "MDS-AW-01"))

        // Disinfectant Wipes - GOOD STOCK with EXPIRING, reorder=6
        // Purchased: 18, will use ~6, stock ~12
        // BEST: Darby at $11.50
        modelContext.insert(Purchase(item: disinfectantWipes, vendor: darby, date: daysAgo(150), quantity: 10, pricePerUnit: 11.50, lotNumber: "DD-DW-003", expirationDate: daysFromNow(10))) // CRITICAL
        modelContext.insert(Purchase(item: disinfectantWipes, vendor: emergencyDental, date: daysAgo(30), quantity: 8, pricePerUnit: 18.00, lotNumber: "ED-DW-001", expirationDate: daysFromNow(365)))

        // Barrier Film - HIGH STOCK, reorder=8
        // Purchased: 30, will use ~8, stock ~22
        // BEST: Darby at $28.00
        modelContext.insert(Purchase(item: barrierFilm, vendor: darby, date: daysAgo(45), quantity: 18, pricePerUnit: 28.00, lotNumber: "DD-BF-445"))
        modelContext.insert(Purchase(item: barrierFilm, vendor: premiumSupplies, date: daysAgo(15), quantity: 12, pricePerUnit: 35.00, lotNumber: "PS-BF-001"))

        // MARK: - Usage Records
        // Carefully balanced so no item goes negative

        // Gloves Medium - use ~30 of 80 purchased
        for day in [1, 2, 3, 5, 7, 8, 10, 12, 15, 18] {
            modelContext.insert(Usage(item: nitrileGlovesM, date: daysAgo(day), quantity: 3, notes: "", isEstimate: false))
        }

        // Gloves Small - use ~20 of 50 purchased
        for day in [1, 3, 5, 8, 10, 12, 15, 18, 22, 25] {
            modelContext.insert(Usage(item: nitrileGlovesS, date: daysAgo(day), quantity: 2, notes: "", isEstimate: false))
        }

        // Gloves Large - use ~15 of 20 purchased (LOW STOCK scenario)
        for day in [1, 2, 3, 5, 7, 8, 10, 12, 15, 18, 20, 22, 25, 28, 30] {
            modelContext.insert(Usage(item: nitrileGlovesL, date: daysAgo(day), quantity: 1, notes: "", isEstimate: false))
        }

        // Face Masks - use ~8 of 25 purchased
        for day in [2, 5, 10, 14, 18, 22, 26, 30] {
            modelContext.insert(Usage(item: faceMasks, date: daysAgo(day), quantity: 1, notes: "", isEstimate: false))
        }

        // Dental Bibs - use ~4 of 12 purchased
        for day in [5, 12, 19, 26] {
            modelContext.insert(Usage(item: dentalBibs, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // Sterilization Pouches - use ~10 of 30 purchased
        for day in [1, 3, 5, 8, 10, 12, 15, 18, 22, 26] {
            modelContext.insert(Usage(item: sterilizationPouches, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // Composite A2 - use ~6 of 18 purchased
        for day in [3, 8, 14, 20, 25, 30] {
            modelContext.insert(Usage(item: compositA2, date: daysAgo(day), quantity: 1, notes: "Restorations", isEstimate: false))
        }

        // Composite A3 - use ~4 of 14 purchased
        for day in [5, 12, 20, 28] {
            modelContext.insert(Usage(item: compositA3, date: daysAgo(day), quantity: 1, notes: "", isEstimate: false))
        }

        // Bonding Agent - use ~4 of 6 purchased (LOW STOCK scenario)
        for day in [3, 10, 18, 26] {
            modelContext.insert(Usage(item: bondingAgent, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // Etch Gel - use ~8 of 25 purchased
        for day in [2, 5, 9, 13, 17, 21, 25, 29] {
            modelContext.insert(Usage(item: etchGel, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // Lidocaine - use ~5 of 15 purchased
        for day in [2, 8, 14, 20, 27] {
            modelContext.insert(Usage(item: lidocaine, date: daysAgo(day), quantity: 1, notes: "", isEstimate: false))
        }

        // Dental Needles - use ~6 of 22 purchased
        for day in [2, 6, 10, 15, 21, 28] {
            modelContext.insert(Usage(item: dentalNeedles, date: daysAgo(day), quantity: 1, notes: "", isEstimate: false))
        }

        // Cotton Rolls - use ~5 of 15 purchased
        for day in [3, 8, 14, 22, 30] {
            modelContext.insert(Usage(item: cottonRolls, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // Gauze - use ~5 of 20 purchased
        for day in [4, 10, 16, 23, 29] {
            modelContext.insert(Usage(item: gauze, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // Prophy Paste - use ~3 of 10 purchased
        for day in [5, 15, 25] {
            modelContext.insert(Usage(item: prophyPaste, date: daysAgo(day), quantity: 1, notes: "Hygiene appointments", isEstimate: false))
        }

        // Fluoride Varnish - use ~3 of 5 purchased (LOW STOCK scenario)
        for day in [5, 15, 25] {
            modelContext.insert(Usage(item: fluorideVarnish, date: daysAgo(day), quantity: 1, notes: "", isEstimate: false))
        }

        // Alginate - use ~4 of 16 purchased
        for day in [7, 14, 21, 28] {
            modelContext.insert(Usage(item: alginate, date: daysAgo(day), quantity: 1, notes: "Study models", isEstimate: false))
        }

        // PVS - use ~5 of 18 purchased
        for day in [5, 12, 18, 24, 30] {
            modelContext.insert(Usage(item: pvsSyringe, date: daysAgo(day), quantity: 1, notes: "Crown impressions", isEstimate: false))
        }

        // Temp Crown - use ~3 of 10 purchased
        for day in [5, 15, 26] {
            modelContext.insert(Usage(item: tempCrown, date: daysAgo(day), quantity: 1, notes: "", isEstimate: false))
        }

        // Saliva Ejectors - use ~8 of 25 purchased
        for day in [1, 4, 8, 12, 16, 20, 24, 28] {
            modelContext.insert(Usage(item: suctionTips, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // HVE Tips - use ~5 of 14 purchased
        for day in [3, 9, 15, 22, 29] {
            modelContext.insert(Usage(item: hveSuction, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // Air/Water Tips - use ~6 of 18 purchased
        for day in [2, 7, 12, 17, 23, 28] {
            modelContext.insert(Usage(item: airWaterTips, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // Disinfectant Wipes - use ~6 of 18 purchased
        for day in [1, 6, 11, 16, 22, 27] {
            modelContext.insert(Usage(item: disinfectantWipes, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        // Barrier Film - use ~8 of 30 purchased
        for day in [1, 5, 9, 13, 17, 21, 25, 29] {
            modelContext.insert(Usage(item: barrierFilm, date: daysAgo(day), quantity: 1, notes: "", isEstimate: true))
        }

        try? modelContext.save()
    }
}
