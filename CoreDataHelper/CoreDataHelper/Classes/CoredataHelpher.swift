//
//  CoredataHelpher.swift
//  Heal
//
//  Created by Jailani on 05/12/19.
//  Copyright © 2019 jai. All rights reserved.
//

import UIKit
import CoreData

protocol CoreDataDetails {
    @available(iOS 10.0, *)
    var persistentContainer : NSPersistentContainer{ get }
    var managedContext : NSManagedObjectContext{ get }
}

protocol MapModelWithManagedObject {
    func map<E:NSManagedObject>(entity: inout E)
    func predicate() -> NSPredicate?
    func getEntityType <E:NSManagedObject> () -> E.Type?
    func relationShipsModels() -> [[MapModelWithManagedObject]]
}

class CoredataHelpher {
    var coreData: CoreDataDetails
    init?(_coreData: CoreDataDetails) {
        coreData = _coreData
    }
    
    private func retriveEntity <E:NSManagedObject>(predicate: NSPredicate?, entity: E.Type) -> [E]? {
        var results : [E]? = nil
        let request = NSFetchRequest<E>(entityName: String(describing: entity))
        do {
            if let _predicate = predicate {
                request.predicate = _predicate
            }
            results = try coreData.managedContext.fetch(request)
        } catch let error as NSError {
            let entityName = String(describing: entity)
            print("Couldn't fetch record for \(entityName) \n \(error) \n \(error.userInfo)")
        }
        return results
    }

    func retriveEntity <E:NSManagedObject, M: MapModelWithManagedObject> (model: M) -> [E]? {
        let entity: E.Type? = model.getEntityType()
        var results: [E]? = nil
        if let entityName = entity {
            results = self.retriveEntity(predicate: model.predicate(), entity: entityName)
        }
        return results
    }

    func createRecord <E : NSManagedObject> (entity: E.Type) -> E? {
        var newEntity: E?
        let entityDescription = NSEntityDescription.entity(forEntityName: String(describing: entity), in: coreData.managedContext)
        if let entityDescription = entityDescription {
            newEntity = NSManagedObject(entity: entityDescription, insertInto: coreData.managedContext) as? E
        }
        return newEntity
    }
    
    private func saveContext() {
        if coreData.managedContext.hasChanges {
            do {
                try coreData.managedContext.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func insertRelations<M: MapModelWithManagedObject>(model: M) {
        let relationShips = model.relationShipsModels()
        for modelObj in relationShips {
            if let _modelObj = modelObj as? M {
                self.insertEntity(model: _modelObj)
            }
        }
    }

    func insertEntity<M: MapModelWithManagedObject>(model:M) {
        if let results = self.retriveEntity(model: model) {
            if results.count == 0 {
                var entity:NSManagedObject?
                if let entityType = model.getEntityType() {
                    entity = self.createRecord(entity: entityType)
                    
                    if var newEntry = entity {
                        model.map(entity: &newEntry)
                        self.insertRelations(model: model)
                        self.saveContext()
                    }
                }
            }
        }
    }
    
    func deleteEntity<M: MapModelWithManagedObject>(model: M) {
        if let lists = self.retriveEntity(model: model) {
            if lists.count != 0 {
                for item in lists {
                    coreData.managedContext.delete(item)
                }
            }
            else {
                print("No matching items to delete")
            }
        }
    }
}
