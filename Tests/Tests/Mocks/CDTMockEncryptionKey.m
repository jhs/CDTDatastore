//
//  CDTMockEncryptionKey.m
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

#import "CDTMockEncryptionKey.h"

@interface CDTMockEncryptionKey ()

@end

@implementation CDTMockEncryptionKey

#pragma mark - CDTEncryptionKey methods
- (NSString *)encryptionKeyOrNil { return @"???"; }

#pragma mark - NSCopying methods
- (id)copyWithZone:(NSZone *)zone { return [[[self class] alloc] init]; }

@end