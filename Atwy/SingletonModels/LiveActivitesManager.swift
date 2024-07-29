//
//  LiveActivitesManager.swift
//  Atwy
//
//  Created by Antoine Bollengier on 14.03.2024.
//  Copyright © 2024 Antoine Bollengier. All rights reserved.
//  

import ActivityKit
import Combine
import BackgroundTasks

@available(iOS 16.1, *)
class LiveActivitesManager {
    static let shared = LiveActivitesManager()
    
    var activities: [(bgActivity: any BackgroundFetchActivity, actualActivity: any CastedActivity)] = []
    var activitiesObservers: [(bgActivity: any BackgroundFetchActivity, observer: AnyCancellable)] = []
        
    func getAuthorizationStatus() -> Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    func removeAllActivities() {
        Task {
            for activity in Activity<DownloaderProgressActivity.ActivityAttributesType>.activities {
                if #available(iOS 16.2, *) {
                    await activity.end(nil, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: nil, dismissalPolicy: .immediate)
                }
            }
        }
    }

    func updateActivity<BGActivityType: BackgroundFetchActivity>(withNewState newState: BGActivityType.ActivityAttributesType.ContentState, bgActivity: BGActivityType) {
        Task {
            guard let actualActivity = self.activityForBGActivity(bgActivity) else { return }
            if #available(iOS 16.2, *) {
                await actualActivity.update(.init(state: newState, staleDate: nil))
            } else {
                await actualActivity.update(using: newState)
            }
        }
    }
    
    func addActivity<T: BackgroundFetchActivity>(_ bgActivity: T, attributes: T.ActivityAttributesType, state: T.ActivityAttributesType.ContentState) throws -> Activity<T.ActivityAttributesType> {
        let activity: Activity<T.ActivityAttributesType>
        
        if #available(iOS 16.2, *) {
            activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } else {
            activity = try Activity.request(attributes: attributes, contentState: state)
        }
        self.activities.append((bgActivity, activity))
        
        return activity
    }
    
    func stopActivity<T: BackgroundFetchActivity>(bgActivity: T) async {
        if let currentActivity = self.activityForBGActivity(bgActivity) {
            if #available(iOS 16.2, *) {
                await currentActivity.end(.init(state: bgActivity.getNewData(), staleDate: nil), dismissalPolicy: .immediate)
            } else {
                await currentActivity.end(using: bgActivity.getNewData(), dismissalPolicy: .immediate)
            }
            
            self.activities.removeAll(where: {($0.bgActivity as? T) == bgActivity})
            self.observerForBGActivity(bgActivity)?.cancel()
            self.activitiesObservers.removeAll(where: {($0 as? T) == bgActivity})
            
            // Stop background fetching
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: T.identifier)
        }
    }
    
    func activityForBGActivity<T: BackgroundFetchActivity>(_ bgActivity: T) -> Activity<T.ActivityAttributesType>? {
        return self.activities.first(where: {($0.bgActivity as? T) == bgActivity})?.actualActivity as? Activity<T.ActivityAttributesType>
    }
    
    func observerForBGActivity<T: BackgroundFetchActivity>(_ bgActivity: T) -> AnyCancellable? {
        return self.activitiesObservers.first(where: {($0 as? T) == bgActivity})?.observer
    }
}

protocol CastedActivity {}

@available(iOS 16.1, *)
extension Activity: CastedActivity {}
