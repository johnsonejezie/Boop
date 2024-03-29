//
//  BPUserData.m
//  Boop
//
//  Created by Johnson Ejezie on 5/16/15.
//  Copyright (c) 2015 Johnson Ejezie. All rights reserved.
//

#import "BPUserData.h"


@implementation BPUserData


-(id)init:(CKRecord *)currentUserData
    selectedForChat:(CKRecord *)selectedForChat
    currentUserContacts:(NSMutableArray *)currentUserContacts
    currentUserFBResponse: (NSDictionary *)currentUserFBResponse
    currentUserContactsFBResponse: (NSMutableArray *)currentUserContactsFBResponse selectedFriend:(CKRecord*)selectedFriend
{
    self = [super init];
    if (self) {
        _currentUserData = currentUserData;
        _currentUserContacts = currentUserContacts;
        _currentUserContactsFBResponse = currentUserContactsFBResponse;
        _currentUserFBResponse = currentUserFBResponse;
        _selectedFriend = selectedFriend;
        _selectedForChat = _selectedForChat;
        _closeTutorialPage = NO;
    }
    return self;
}

+(BPUserData *)sharedInstance {
    
    static BPUserData *_sharedInstance = nil;
    
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[BPUserData alloc] init];
    });
    return _sharedInstance;
}

-(void)saveUser:(NSDictionary *)userData completion:(void (^)(void))completionBlock {
    
    
    self.bpContainer = [CKContainer defaultContainer];
    self.bpPublicDatabase = [self.bpContainer publicCloudDatabase];
    self.typeOfUser = @"BU";
    
    [self.bpContainer fetchUserRecordIDWithCompletionHandler:^(CKRecordID *recordID, NSError *error) {
        if (!error) {
            CKRecordID *userRecordIDString = [[CKRecordID alloc] initWithRecordName:[NSString stringWithFormat:@"%@%@",self.typeOfUser, recordID.recordName]];
            NSLog(@"the formated id %@",userRecordIDString);
            CKRecord *bpUserRecord = [[CKRecord alloc] initWithRecordType:@"boopUsers" recordID:userRecordIDString];
            bpUserRecord[@"firstName"] = [userData[@"first_name"] capitalizedString];
            bpUserRecord[@"lastName"] = [userData[@"last_name"] capitalizedString];
            bpUserRecord[@"link" ] = userData[@"link"];
            bpUserRecord[@"registeredBoopUser"] = @"YES";
            bpUserRecord[@"picture"] = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=large", userData[@"id"]];
            bpUserRecord[@"id"] = userData[@"id"];
            bpUserRecord[@"email"] = userData[@"email"];
            bpUserRecord[@"gender"] = userData[@"gender"];
            // set current user record for use when referencing ghost.
            // self.currentUserData = bpUserRecord;
            NSLog(@"record to save %@",  self.currentUserData);
            self.currentUserData = bpUserRecord;
            [self.bpPublicDatabase saveRecord:bpUserRecord completionHandler:^(CKRecord *record, NSError *error) {
                if (!error) {
                    NSLog(@"saved user %@", record);
                    [self saveUserContact:self.currentUserContactsFBResponse completion:^{
                          NSLog(@"User contacts populated");
                    }];
                }else {
                   NSLog(@"error saving user %@ error code is: %ld", error, (long)error.code);
                    NSLog(@"contacts count %lu",(unsigned long)self.currentUserContactsFBResponse.count );
                         NSLog(@"contacts count %@",self.currentUserContactsFBResponse);
                    [self saveUserContact:self.currentUserContactsFBResponse completion:^{
                        NSLog(@"User contacts populated");
                        [self fetchUserContact:^{
                            NSLog(@"done fetching contact");
                        }];
                    }];
                }
                completionBlock();
            }];
        }else {
            NSLog(@"error fetching user %@", error);
            completionBlock();
        }
        
    }];
}

-(void)saveUserContact:(NSMutableArray *)userContacts completion:(void (^)(void))completionBlock {
    
    for (NSDictionary* contact in userContacts) {
        
        self.typeOfUser = @"BGU";
        CKRecordID *userRecordID = [[CKRecordID alloc] initWithRecordName:[NSString stringWithFormat:@"%@%@",self.typeOfUser, contact[@"name"]]];
        CKRecord *userRecord = [[CKRecord alloc] initWithRecordType:@"boopUsers" recordID:userRecordID];
//        CKRecord* userRecord = [[CKRecord alloc]initWithRecordType:@"boopUsers"];
        userRecord[@"name"] = contact[@"name"];
        userRecord[@"picture"] = contact[@"picture"][@"data"][@"url"];
        userRecord[@"registeredKnotworkUser"] = @"NO";  //        BOOL boolValue = [myString boolValue]
        userRecord[@"id"] = contact[@"id"];
        
        CKReference* ref = [[CKReference alloc] initWithRecord:self.currentUserData action:CKReferenceActionNone];
//
        NSMutableArray *testArray = [NSMutableArray array];
        [testArray addObject:ref];
        userRecord[@"contactList"] = testArray;
        
        [self.bpPublicDatabase saveRecord:userRecord completionHandler:^(CKRecord *savedRecord, NSError *saveError) {
            if (!saveError) {
                 NSLog(@"contact record %@",savedRecord );
            }else {
                NSLog(@"error %@", saveError);
            }
           
        }];
    }
    completionBlock();
}

-(void)fetchUserContact:(void (^)(void))completionBlock{

    CKContainer* myContainer  = [CKContainer defaultContainer];
    CKDatabase* publicDatabase = [myContainer publicCloudDatabase];
    CKReference* recordToMatch = [[CKReference alloc] initWithRecordID:[BPUserData sharedInstance].currentUserData.recordID action:CKReferenceActionNone];
    dispatch_async(dispatch_get_main_queue(), ^(void){
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"contactList CONTAINS %@",recordToMatch];
        CKQuery *query = [[CKQuery alloc] initWithRecordType:@"boopUsers" predicate:predicate];
        [publicDatabase performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
            if (error) {
                // Error handling for failed fetch from public database
                NSLog(@"error querying knotwork users %@", error);
            }
            else {
                // Display the fetched records
                NSLog(@"result for contacts %@", results);
                self.currentUserContacts = results;
                
                NSLog(@"result for self.currentContacts %@", self.currentUserContacts);
            }
        }];
        
    });
}

-(void)boopSomeone:(NSString*)message completion:(void (^)(void))completionBlock {
    
    NSString* currentUserName = [NSString stringWithFormat:@"%@ %@", [BPUserData sharedInstance].currentUserData[@"firstName"], [BPUserData sharedInstance].currentUserData[@"lastName"]];
    
    self.bpContainer  = [CKContainer defaultContainer];
    self.bpPublicDatabase = [self.bpContainer publicCloudDatabase];
    CKRecordID *booperID = [[CKRecordID alloc] initWithRecordName:[NSString stringWithFormat:@"BU%@",self.currentUserData.recordID]];
    CKRecordID *selectedFriendID = [[CKRecordID alloc] initWithRecordName:self.selectedFriend.recordID.recordName];
    
    [self.bpPublicDatabase fetchRecordWithID:self.currentUserData.recordID completionHandler:^(CKRecord *record, NSError *error) {
        if (!error) {
            
            CKReference* ref1 = [[CKReference alloc] initWithRecord:record action:CKReferenceActionNone];
            CKReference* ref2 = [[CKReference alloc] initWithRecordID:selectedFriendID action:CKReferenceActionNone];
            CKRecord *boopRecord = [[CKRecord alloc] initWithRecordType:@"booped"];
            
            boopRecord[@"booperID"] = [BPUserData sharedInstance].currentUserData.recordID.recordName;
            boopRecord[@"booperName"] = currentUserName;
            boopRecord[@"booperPicture"] = [BPUserData sharedInstance].currentUserData[@"picture"];
            
            boopRecord[@"boopeeID"] = [BPUserData sharedInstance].selectedFriend.recordID.recordName;
            boopRecord[@"boopeeName"] = [BPUserData sharedInstance].selectedFriend[@"name"];
            boopRecord[@"boopeePicture"] = [BPUserData sharedInstance].selectedFriend[@"picture"];
            
            boopRecord[@"message"] = message;
            
            NSMutableArray *refs = [NSMutableArray new];
            [refs addObjectsFromArray:boopRecord[@"reference"]];
            //
            [refs addObject:ref1];
            [refs addObject:ref2];
            boopRecord[@"reference" ] =refs;
            
            [self.bpPublicDatabase saveRecord:boopRecord completionHandler:^(CKRecord *boopRecord, NSError *error) {
                if (!error) {
                    NSLog(@"booped completed %@", boopRecord);
                }else {
                    NSLog(@"an error occured %@", error);
                }
            }];


            
            NSLog(@"fetched %@", record);
        }else {
           NSLog(@"error %@", error);
        }
    }];
    completionBlock();
    
}


@end
