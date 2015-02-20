//
//  IndexManagerEncryptionTests.m
//  Tests
//
//  Created by Enrique de la Torre Fernandez on 23/02/2015.
//  Copyright (c) 2015 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import <XCTest/XCTest.h>

#import "CloudantSyncTests.h"
#import "CDTEncryptionKeyDummy.h"
#import "CDTDatastoreManager.h"

#import "CDTIndexManager.h"

@interface IndexManagerEncryptionTests : CloudantSyncTests

@end

@implementation IndexManagerEncryptionTests

- (void)setUp
{
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the
    // class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the
    // class.

    [super tearDown];
}

- (void)testCreateIndexManagerWithDummyKey
{
    CDTEncryptionKeyDummy *dummy = [CDTEncryptionKeyDummy dummy];
    CDTDatastore *datastore =
        [self.factory datastoreNamed:@"test" withEncryptionKey:dummy error:nil];

    NSError *err = nil;
    CDTIndexManager *im = [[CDTIndexManager alloc] initWithDatastore:datastore error:&err];

    XCTAssertNotNil(im, @"indexManager is not nil");
    XCTAssertNil(err, @"error has to be nil");
}

@end