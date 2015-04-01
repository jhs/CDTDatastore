//
//  CDTSecurityUtils.m
//
//
//  Created by Enrique de la Torre Fernandez on 20/03/2015.
//
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//

#import "CDTSecurityUtils.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>

#import <openssl/evp.h>
#import <openssl/aes.h>

#import "CDTSecurityConstants.h"
#import "CDTSecurityCustomBase64Utils.h"

@interface CDTSecurityUtils ()

@property (strong, nonatomic, readonly) id<CDTSecurityBase64Utils> base64Utils;

@end

@implementation CDTSecurityUtils

#pragma mark - Init object
- (instancetype)init
{
    return [self initWithBase64Utils:[[CDTSecurityCustomBase64Utils alloc] init]];
}

- (instancetype)initWithBase64Utils:(id<CDTSecurityBase64Utils>)base64Utils
{
    NSAssert(base64Utils, @"Base64 util is mandatory");

    self = [super init];
    if (self) {
        _base64Utils = base64Utils;
    }

    return self;
}

#pragma mark - Public class methods
- (NSString *)generateRandomStringWithBytes:(int)bytes
{
    uint8_t randBytes[bytes];

    int rc = SecRandomCopyBytes(kSecRandomDefault, (size_t)bytes, randBytes);
    if (rc != 0) {
        return nil;
    }

    NSMutableString *hexEncoded = [NSMutableString new];
    for (int i = 0; i < bytes; i++) {
        [hexEncoded appendString:[NSString stringWithFormat:@"%02x", randBytes[i]]];
    }

    NSString *randomStr = [NSString stringWithFormat:@"%@", hexEncoded];

    return randomStr;
}

- (NSString *)encryptWithKey:(NSString *)key
                        withText:(NSString *)text
                          withIV:(NSString *)iv
    covertBase64BeforeEncryption:(BOOL)covertBase64BeforeEncryptionFlag
{
    if (![text isKindOfClass:[NSString class]] || [text length] < 1) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_ENCRYPT
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_EMPTY_TEXT];
    }

    if (![key isKindOfClass:[NSString class]] || [key length] < 1) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_ENCRYPT
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_EMPTY_KEY];
    }

    if (![iv isKindOfClass:[NSString class]] || [iv length] < 1) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_ENCRYPT
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_EMPTY_IV];
    }

    if (covertBase64BeforeEncryptionFlag) {
        NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
        text = [self.base64Utils base64StringFromData:data length:(int)text.length isSafeUrl:NO];
    }

    NSData *cipherDat = [CDTSecurityUtils doEncrypt:text key:key withIV:iv];

    NSString *encodedBase64CipherString =
        [self.base64Utils base64StringFromData:cipherDat length:(int)text.length isSafeUrl:NO];
    return encodedBase64CipherString;
}

- (NSString *)decryptWithKey:(NSString *)key
                 withCipherText:(NSString *)ciphertext
                         withIV:(NSString *)iv
    decodeBase64AfterDecryption:(BOOL)decodeBase64AfterDecryption
            checkBase64Encoding:(BOOL)checkBase64Encoding;
{
    if (![ciphertext isKindOfClass:[NSString class]] || [ciphertext length] < 1) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_DECRYPT
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_EMPTY_CIPHER];
    }

    if (![key isKindOfClass:[NSString class]] || [key length] < 1) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_DECRYPT
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_EMPTY_KEY];
    }

    if (![iv isKindOfClass:[NSString class]] || [iv length] < 1) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_DECRYPT
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_EMPTY_IV];
    }

    NSString *returnText = [self decryptWithKey:key
                                 withCipherText:ciphertext
                                         withIV:iv
                            checkBase64Encoding:checkBase64Encoding];

    if (returnText != nil && decodeBase64AfterDecryption) {
        NSData *inputBase64Data = [self.base64Utils base64DataFromString:returnText];
        returnText = [[NSString alloc] initWithData:inputBase64Data encoding:NSUTF8StringEncoding];
    }

    return returnText;
}

- (NSString *)generateKeyWithPassword:(NSString *)pass
                              andSalt:(NSString *)salt
                        andIterations:(NSInteger)iterations
{
    if (iterations < 1) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_KEYGEN
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_INVALID_ITERATIONS];
    }

    if (![pass isKindOfClass:[NSString class]] || [pass length] < 1) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_KEYGEN
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_EMPTY_PASSWORD];
    }

    if (![salt isKindOfClass:[NSString class]] || [salt length] < 1) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_KEYGEN
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_EMPTY_SALT];
    }

    NSData *passData = [pass dataUsingEncoding:NSUTF8StringEncoding];
    NSData *saltData = [salt dataUsingEncoding:NSUTF8StringEncoding];

    NSMutableData *derivedKey = [NSMutableData dataWithLength:kCCKeySizeAES256];

    int retVal = CCKeyDerivationPBKDF(kCCPBKDF2, passData.bytes, pass.length, saltData.bytes,
                                      salt.length, kCCPRFHmacAlgSHA1, (int)iterations,
                                      derivedKey.mutableBytes, kCCKeySizeAES256);

    if (retVal != kCCSuccess) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL_KEYGEN
                    format:@"Return value: %d", retVal];
    }

    NSMutableString *derivedKeyStr = [NSMutableString stringWithCapacity:kCCKeySizeAES256 * 2];
    const unsigned char *dataBytes = [derivedKey bytes];

    for (int idx = 0; idx < kCCKeySizeAES256; idx++) {
        [derivedKeyStr appendFormat:@"%02x", dataBytes[idx]];
    }

    derivedKey = nil;
    dataBytes = nil;

    return [NSString stringWithString:derivedKeyStr];
}

#pragma mark - Public class methods
+ (instancetype)util { return [[[self class] alloc] init]; }

+ (instancetype)utilWithBase64Utils:(id<CDTSecurityBase64Utils>)base64Utils
{
    return [[[self class] alloc] initWithBase64Utils:base64Utils];
}

#pragma mark - Private methods: Encryption and Decryption
- (NSString *)decryptWithKey:(NSString *)key
              withCipherText:(NSString *)ciphertext
                      withIV:(NSString *)iv
         checkBase64Encoding:(BOOL)checkBase64Encoding
{
    NSData *decodedCipher = [self doDecrypt:ciphertext key:key withIV:iv];

    NSString *returnText =
        [[NSString alloc] initWithData:decodedCipher encoding:NSUnicodeStringEncoding];

    if (returnText != nil) {
        if (checkBase64Encoding && ![self.base64Utils isBase64Encoded:returnText]) {
            returnText = nil;
        }
    }

    return returnText;
}

- (NSData *)doDecrypt:(NSString *)ciphertextEncoded key:(NSString *)key withIV:(NSString *)iv
{
    NSData *cipherText = [self.base64Utils base64DataFromString:ciphertextEncoded];

    unsigned char *nativeKey = [CDTSecurityUtils getNativeKeyFromHexString:key];
    unsigned char *nativeIv = [CDTSecurityUtils getNativeIVFromHexString:iv];

    EVP_CIPHER_CTX ctx;
    EVP_CIPHER_CTX_init(&ctx);
    EVP_DecryptInit_ex(&ctx, EVP_aes_256_cbc(), NULL, nativeKey, nativeIv);

    unsigned char *cipherTextBytes = (unsigned char *)[cipherText bytes];
    int cipherTextBytesLength = (int)[cipherText length];

    unsigned char *decryptedBytes = aes_decrypt(&ctx, cipherTextBytes, &cipherTextBytesLength);
    NSData *decryptedData = [NSData dataWithBytes:decryptedBytes length:cipherTextBytesLength];

    EVP_CIPHER_CTX_cleanup(&ctx);

    bzero(decryptedBytes, cipherTextBytesLength);
    free(decryptedBytes);

    bzero(nativeKey, CDTkChosenCipherKeySize);
    free(nativeKey);

    bzero(nativeIv, CDTkChosenCipherIVSize);
    free(nativeIv);

    return decryptedData;
}

#pragma mark - Private class methods
+ (NSData *)doEncrypt:(NSString *)text key:(NSString *)key withIV:(NSString *)iv
{
    NSData *myText = [text dataUsingEncoding:NSUnicodeStringEncoding];

    unsigned char *nativeIv = [CDTSecurityUtils getNativeIVFromHexString:iv];
    unsigned char *nativeKey = [CDTSecurityUtils getNativeKeyFromHexString:key];

    EVP_CIPHER_CTX ctx;
    EVP_CIPHER_CTX_init(&ctx);
    EVP_EncryptInit_ex(&ctx, EVP_aes_256_cbc(), NULL, nativeKey, nativeIv);

    unsigned char *textBytes = (unsigned char *)[myText bytes];
    int textBytesLength = (int)[myText length];

    unsigned char *encryptedBytes = aes_encrypt(&ctx, textBytes, &textBytesLength);
    NSData *encryptedData = [NSData dataWithBytes:encryptedBytes length:textBytesLength];

    EVP_CIPHER_CTX_cleanup(&ctx);

    bzero(encryptedBytes, textBytesLength);
    free(encryptedBytes);

    bzero(nativeKey, CDTkChosenCipherKeySize);
    free(nativeKey);

    bzero(nativeIv, CDTkChosenCipherIVSize);
    free(nativeIv);

    return encryptedData;
}

/*
 * Caller MUST FREE the memory returned from this method
 */
+ (unsigned char *)getNativeIVFromHexString:(NSString *)iv
{
    /*
     Make sure the key length represents 32 byte (256 bit) values. The string represent the
     hexadecimal
     values that should be used, so the string "4962" represents byte values 0x49  0x62.
     Note that the constant value is the actual byte size, and the strings are twice that size
     since every two characters in the string corresponds to a single byte.
     */
    if ([iv length] != (NSUInteger)(CDTkChosenCipherIVSize * 2)) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL
                    format:@"%@", CDTDATASTORE_SECURITY_ERROR_MSG_INVALID_IV_LENGTH];
    }

    unsigned char *nativeIv = malloc(CDTkChosenCipherIVSize);

    int i;
    for (i = 0; i < CDTkChosenCipherIVSize; i++) {
        int hexStrIdx = i * 2;
        NSString *hexChrStr = [iv substringWithRange:NSMakeRange(hexStrIdx, 2)];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexChrStr];
        uint currInt;
        [scanner scanHexInt:&currInt];
        nativeIv[i] = (char)currInt;
    }

    return nativeIv;
}

/*
 * Caller MUST FREE the memory returned from this method
 */
+ (unsigned char *)getNativeKeyFromHexString:(NSString *)key
{
    /*
     Make sure the key length represents 32 byte (256 bit) values. The string represent the
     hexadecimal
     values that should be used, so the string "4962" represents byte values 0x49  0x62.
     Note that the constant value is the actual byte size, and the strings are twice that size
     since every two characters in the string corresponds to a single byte.
     */
    if ([key length] != (NSUInteger)(CDTkChosenCipherKeySize * 2)) {
        [NSException raise:CDTDATASTORE_SECURITY_ERROR_LABEL
                    format:@"Key must be 64 hex characters or 32 bytes (256 bits)"];
    }

    unsigned char *nativeKey = malloc(CDTkChosenCipherKeySize);

    int i;
    for (i = 0; i < CDTkChosenCipherKeySize; i++) {
        int hexStrIdx = i * 2;
        NSString *hexChrStr = [key substringWithRange:NSMakeRange(hexStrIdx, 2)];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexChrStr];
        uint currInt;
        [scanner scanHexInt:&currInt];
        nativeKey[i] = (char)currInt;
    }

    return nativeKey;
}

/*
 * Caller MUST FREE memory returned from this method
 * Decryption using OpenSSL decryption aes256
 * Decrypt *len bytes of ciphertext
 */
static unsigned char *aes_decrypt(EVP_CIPHER_CTX *e, unsigned char *ciphertext, int *len)
{
    /* plaintext will always be equal to or lesser than length of ciphertext*/
    int p_len = *len, f_len = 0;
    unsigned char *plaintext = malloc(p_len + AES_BLOCK_SIZE);
    
    EVP_DecryptInit_ex(e, NULL, NULL, NULL, NULL);
    EVP_DecryptUpdate(e, plaintext, &p_len, ciphertext, *len);
    EVP_DecryptFinal_ex(e, plaintext+p_len, &f_len);
    
    *len = p_len + f_len;
    return plaintext;
}

/*
 * Caller MUST FREE memory returned from this method
 * Encryption using OpenSSL encryption aes256
 * Encrypt *len bytes of data
 * All data going in & out is considered binary (unsigned char[])
 */
static unsigned char *aes_encrypt(EVP_CIPHER_CTX *e, unsigned char *plaintext, int *len)
{
    /* max ciphertext len for a n bytes of plaintext is n + AES_BLOCK_SIZE -1 bytes */
    int c_len = *len + AES_BLOCK_SIZE, f_len = 0;
    unsigned char *ciphertext = malloc(c_len);

    /* allows reusing of 'e' for multiple encryption cycles */
    EVP_EncryptInit_ex(e, NULL, NULL, NULL, NULL);

    /* update ciphertext, c_len is filled with the length of ciphertext generated,
     *len is the size of plaintext in bytes */
    EVP_EncryptUpdate(e, ciphertext, &c_len, plaintext, *len);

    /* update ciphertext with the final remaining bytes */
    EVP_EncryptFinal_ex(e, ciphertext + c_len, &f_len);

    *len = c_len + f_len;
    return ciphertext;
}

@end