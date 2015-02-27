//
//  ForwardSenterItem.m
//  Messenger for Telegram
//
//  Created by keepcoder on 18.03.14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "ForwardSenterItem.h"
#import "NSArray+BlockFiltering.h"
#import "MessageTableItem.h"




@interface ForwardSenterItem ()


@end


@implementation ForwardSenterItem

-(void)setState:(MessageState)state {
    [super setState:state];
}


-(id)initWithMessages:(NSArray *)msgs forConversation:(TL_conversation *)conversation {
    if(self = [super init]) {
        self.conversation = conversation;
        
        NSMutableArray *ids = [[NSMutableArray alloc] init];
        NSMutableArray *fakes = [[NSMutableArray alloc] init];
        NSMutableArray *copy = [msgs mutableCopy];
        
        [copy sortUsingComparator:^NSComparisonResult(TLMessage * obj1, TLMessage * obj2) {
            return [@(obj1.n_id) compare:@(obj2.n_id)];
        }];
        
        
        
        for (int i = 0; i < copy.count; i++) {
            
            long random = rand_long();
            
            TLMessage *f = copy[i];
            
            [ids addObject:@([f n_id])];
            
            TL_localMessageForwarded *fake = [TL_localMessageForwarded createWithN_id:0 flags:TGOUTUNREADMESSAGE fwd_from_id:f.fwd_from_id ? f.fwd_from_id : f.from_id fwd_date:f.fwd_date ? f.fwd_date : f.date from_id:UsersManager.currentUserId to_id:conversation.peer date:[[MTNetwork instance] getTime] message:f.message media:f.media fakeId:[MessageSender getFakeMessageId] randomId:random fwd_n_id:[f n_id] state:DeliveryStatePending];
            
            [fake save:i == copy.count-1];
            
            [fakes insertObject:fake atIndex:0];
            
        }
        
        
        
        self.msg_ids = ids;
        
        self.fakes = fakes;
        
    }
    
    return self;
}


-(void)setTableItems:(NSArray *)tableItems {
    self->_tableItems = tableItems;
    for (MessageTableItem *item in tableItems) {
        item.messageSender = self;
    }
}

-(void)performRequest {

    if(self.fakes.count == 0) {
        self.state = MessageSendingStateSent;
        return;
    }
    
    NSMutableArray *random_ids = [[NSMutableArray alloc] init];
    
    [self.fakes enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TL_localMessageForwarded  *obj, NSUInteger idx, BOOL *stop) {
        [random_ids addObject:@(obj.randomId)];
    }];
    
    TLAPI_messages_forwardMessages *request = [TLAPI_messages_forwardMessages createWithPeer:self.conversation.inputPeer n_id:[self.msg_ids mutableCopy] random_id:random_ids];
    
    self.rpc_request = [RPCRequest sendRequest:request successHandler:^(RPCRequest *request, TL_messages_statedMessages *response) {
        
         NSArray *messages = [response.messages reversedArray];
        
        [response.messages removeAllObjects];

        [SharedManager proccessGlobalResponse:response];
        
        for(int i = 0; i < messages.count; i++) {
            
            TL_localMessageForwarded *fake = self.fakes[i];
            TLMessage *stated = messages[i];
            
            fake.date = stated.date;
            fake.n_id = stated.n_id;
            fake.dstate = DeliveryStateNormal;
            
            if([fake.media isKindOfClass:[TL_messageMediaPhoto class]]  || [fake.media isKindOfClass:[TL_messageMediaVideo class]]) {
                [[Storage manager] insertMedia:fake];
            }
            
            [fake save:i == 0];
        }
        
        self.state = MessageSendingStateSent;
        
          
        
    } errorHandler:^(RPCRequest *request, RpcError *error) {
        self.state = MessageSendingStateError;
    }];

}

@end
