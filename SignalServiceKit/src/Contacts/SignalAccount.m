//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "NSData+Image.h"
#import "UIImage+OWS.h"
#import <SignalCoreKit/Cryptography.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <SignalServiceKit/Contact.h>
#import <SignalServiceKit/ContactsManagerProtocol.h>
#import <SignalServiceKit/SSKEnvironment.h>
#import <SignalServiceKit/SignalAccount.h>
#import <SignalServiceKit/SignalRecipient.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSUInteger const SignalAccountSchemaVersion = 1;

/* We need to query the system preferences to achieve the behaviour at Messages on iOS.
 
 If we ask NSPersonNameComponentsFormatter for "short" we will get the nickname if it exists but if it _doesn't_ exit we'll just get the first name. (Or the name pattern the user has selected in their system preferences. This means that in the conversation list in the left, where Messages displays the full name of a contact if they don't have a nickname, we'd just display the Short Name. To match the behaviour we ask UserDefaults for the value of this key and prefer to use the nickname, if available, in the conversation list.
*/
static NSString *kSignalPreferNicknamesPreference = @"NSPersonNameDefaultShouldPreferNicknamesPreference";

@interface SignalAccount ()

@property (nonatomic, readonly) NSUInteger accountSchemaVersion;

@property (nonatomic) NSString *multipleAccountLabelText;

@property (nonatomic, nullable) Contact *contact;

// These fields are obsolete and should always be nil.
@property (nonatomic, nullable, readonly) NSData *contactAvatarJpegData;

@end

#pragma mark -

@implementation SignalAccount

+ (BOOL)shouldBeIndexedForFTS
{
    return YES;
}

- (instancetype)initWithSignalRecipient:(SignalRecipient *)signalRecipient
                                contact:(nullable Contact *)contact
                      contactAvatarHash:(nullable NSData *)contactAvatarHash
               multipleAccountLabelText:(nullable NSString *)multipleAccountLabelText
{
    return [self initWithSignalServiceAddress:signalRecipient.address
                                      contact:contact
                            contactAvatarHash:contactAvatarHash
                     multipleAccountLabelText:multipleAccountLabelText];
}

- (instancetype)initWithSignalServiceAddress:(SignalServiceAddress *)serviceAddress
{
    return [self initWithSignalServiceAddress:serviceAddress contact:nil multipleAccountLabelText:nil];
}

- (instancetype)initWithSignalServiceAddress:(SignalServiceAddress *)serviceAddress
                                     contact:(nullable Contact *)contact
                    multipleAccountLabelText:(nullable NSString *)multipleAccountLabelText
{
    return [self initWithSignalServiceAddress:serviceAddress
                                      contact:contact
                            contactAvatarHash:nil
                     multipleAccountLabelText:multipleAccountLabelText];
}

- (instancetype)initWithSignalServiceAddress:(SignalServiceAddress *)serviceAddress
                                     contact:(nullable Contact *)contact
                           contactAvatarHash:(nullable NSData *)contactAvatarHash
                    multipleAccountLabelText:(nullable NSString *)multipleAccountLabelText
{
    OWSAssertDebug(serviceAddress.isValid);
    if (self = [super init]) {
        _recipientUUID = serviceAddress.uuidString;
        _recipientPhoneNumber = serviceAddress.phoneNumber;
        _accountSchemaVersion = SignalAccountSchemaVersion;
        _contact = contact;
        _contactAvatarHash = contactAvatarHash;
        _multipleAccountLabelText = multipleAccountLabelText;
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self) {
        return self;
    }

    // Migrating from an everyone has a phone number world to a
    // world in which we have UUIDs
    if (_accountSchemaVersion == 0) {
        // Rename recipientId to recipientPhoneNumber
        _recipientPhoneNumber = [coder decodeObjectForKey:@"recipientId"];

        OWSAssert(_recipientPhoneNumber != nil);
    }

    _accountSchemaVersion = SignalAccountSchemaVersion;

    return self;
}

- (instancetype)initWithContact:(nullable Contact *)contact
              contactAvatarHash:(nullable NSData *)contactAvatarHash
       multipleAccountLabelText:(NSString *)multipleAccountLabelText
           recipientPhoneNumber:(nullable NSString *)recipientPhoneNumber
                  recipientUUID:(nullable NSString *)recipientUUID
{
    self = [super init];
    if (!self) {
        return self;
    }

    OWSAssertDebug(recipientPhoneNumber != nil || recipientUUID != nil);

    _contact = contact;
    _contactAvatarHash = contactAvatarHash;
    _multipleAccountLabelText = multipleAccountLabelText;
    _recipientPhoneNumber = recipientPhoneNumber;
    _recipientUUID = recipientUUID;
    _accountSchemaVersion = SignalAccountSchemaVersion;

    return self;
}

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
                         contact:(nullable Contact *)contact
               contactAvatarHash:(nullable NSData *)contactAvatarHash
           contactAvatarJpegData:(nullable NSData *)contactAvatarJpegData
        multipleAccountLabelText:(NSString *)multipleAccountLabelText
            recipientPhoneNumber:(nullable NSString *)recipientPhoneNumber
                   recipientUUID:(nullable NSString *)recipientUUID
{
    self = [super initWithGrdbId:grdbId
                        uniqueId:uniqueId];

    if (!self) {
        return self;
    }

    _contact = contact;
    _contactAvatarHash = contactAvatarHash;
    _contactAvatarJpegData = contactAvatarJpegData;
    _multipleAccountLabelText = multipleAccountLabelText;
    _recipientPhoneNumber = recipientPhoneNumber;
    _recipientUUID = recipientUUID;

    return self;
}

// clang-format on

// --- CODE GENERATION MARKER

- (void)sdsFinalizeSignalAccount
{
    _contactAvatarJpegDataObsolete = nil;
}

- (BOOL)shouldUseNicknames
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kSignalPreferNicknamesPreference];
}

- (nullable NSPersonNameComponents *)contactPersonNameComponents
{
    NSPersonNameComponents *nameComponents = [NSPersonNameComponents new];

    // Check if we have a first name or last name, if we do we can use them directly.
    if (self.contactFirstName.length > 0 || self.contactLastName.length > 0) {
        nameComponents.givenName = self.contactFirstName;
        nameComponents.familyName = self.contactLastName;
    } else if (self.contactFullName.length > 0) {
        // If we don't have a first name or last name, but we *do* have a full name,
        // try our best to create appropriate components to represent it.
        NSArray<NSString *> *components = [self.contactFullName componentsSeparatedByString:@" "];

        // If there are only two words separated by a space, this is probably a given
        // and family name.
        if (components.count <= 2) {
            nameComponents.givenName = components.firstObject;
            nameComponents.familyName = components.lastObject;
        } else {
            nameComponents.givenName = self.contactFullName;
        }
    }
    nameComponents.nickname = self.contactNicknameIfAvailable;

    if (nameComponents.givenName.length < 1 && nameComponents.familyName.length < 1
        && nameComponents.nickname.length < 1) {
        return nil;
    }

    return nameComponents;
}

- (nullable NSString *)contactPreferredDisplayName
{
    NSPersonNameComponents *_Nullable components = self.contactPersonNameComponents;
    if (components == nil) {
        return nil;
    }

    NSString *result = nil;
    // If we have a nickname check what the user prefers.
    if (components.nickname.length > 0 && self.shouldUseNicknames) {
        result = components.nickname;
    } else if (components.givenName.length > 0 || components.familyName.length > 0) {
        result = [NSPersonNameComponentsFormatter localizedStringFromPersonNameComponents: components
                                                                                    style: NSPersonNameComponentsFormatterStyleDefault
                                                                                  options: 0];
    } else {
        // The components might have a nickname but !shouldUseNicknames.
        OWSLogWarn(@"Invalid name components.");
        return nil;
    }
    result = result.filterStringForDisplay;
    if (result.length > 0) {
        return result;
    } else {
        return nil;
    }
}

- (nullable NSString *)contactNicknameIfAvailable
{
    if (!self.shouldUseNicknames) {
        return nil;
    }
    NSString *nickname = self.contact.nickname;
    if (nickname.length > 0)
    {
        return nickname;
    }
    else
    {
        return nil;
    }
}

- (nullable NSString *)contactFullName
{
    return self.contact.fullName.filterStringForDisplay;
}

- (nullable NSString *)contactFirstName
{
    return self.contact.firstName.filterStringForDisplay;
}

- (nullable NSString *)contactLastName
{
    return self.contact.lastName.filterStringForDisplay;
}

- (NSString *)multipleAccountLabelText
{
    NSString *_Nullable result = _multipleAccountLabelText.filterStringForDisplay;
    return result != nil ? result : @"";
}

- (SignalServiceAddress *)recipientAddress
{
    return [[SignalServiceAddress alloc] initWithUuidString:self.recipientUUID phoneNumber:self.recipientPhoneNumber];
}

- (BOOL)hasSameContent:(SignalAccount *)other
{
    OWSAssertDebug(other != nil);

    // NOTE: We don't want to compare contactAvatarJpegData.
    //       It can't change without contactAvatarHash changing
    //       as well.
    return ([NSObject isNullableObject:self.recipientPhoneNumber equalTo:other.recipientPhoneNumber] &&
        [NSObject isNullableObject:self.recipientUUID equalTo:other.recipientUUID] &&
        [NSObject isNullableObject:self.contact equalTo:other.contact] &&
        [NSObject isNullableObject:self.multipleAccountLabelText equalTo:other.multipleAccountLabelText] &&
        [NSObject isNullableObject:self.contactAvatarHash equalTo:other.contactAvatarHash]);
}

- (void)anyDidInsertWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidInsertWithTransaction:transaction];

    [self.modelReadCaches.signalAccountReadCache didInsertOrUpdateSignalAccount:self transaction:transaction];
}

- (void)anyDidUpdateWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidUpdateWithTransaction:transaction];

    [self.modelReadCaches.signalAccountReadCache didInsertOrUpdateSignalAccount:self transaction:transaction];
}

- (void)anyDidRemoveWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    [super anyDidRemoveWithTransaction:transaction];

    [self.modelReadCaches.signalAccountReadCache didRemoveSignalAccount:self transaction:transaction];
}

- (void)updateWithContact:(nullable Contact *)contact transaction:(SDSAnyWriteTransaction *)transaction
{
    [self anyUpdateWithTransaction:transaction
                             block:^(SignalAccount *account) {
                                 account.contact = contact;
                             }];
}

#if TESTABLE_BUILD
- (void)replaceContactForTests:(nullable Contact *)contact
{
    self.contact = contact;
}
#endif

@end

NS_ASSUME_NONNULL_END
