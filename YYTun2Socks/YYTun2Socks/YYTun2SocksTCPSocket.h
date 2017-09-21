//
//  YYTun2SocksTCPSocket.h
//  YYTun2Socks
//
//  Created by Hmyy on 2017/9/21.
//
//

#import <Foundation/Foundation.h>
#include <netinet/in.h>
#include "lwip/tcp.h"

@protocol YYTun2SocksTCPSocketDelegate;

@interface YYTun2SocksTCPSocket : NSObject

@property (nonatomic, assign, readonly) struct in_addr sourceAddress;

@property (nonatomic, assign, readonly) struct in_addr destinationAddress;

@property (nonatomic, assign, readonly) UInt16 sourcePort;

@property (nonatomic, assign, readonly) UInt16 destinationPort;

- (instancetype)initWithTCPPcb:(struct tcp_pcb*)pcb delegate:(id<YYTun2SocksTCPSocketDelegate>)delegate queue:(dispatch_queue_t)queue;

- (void)setDelegate:(id<YYTun2SocksTCPSocketDelegate>)delegate;

@end

@protocol YYTun2SocksTCPSocketDelegate <NSObject>

- (void)socketDidCloseLocally:(YYTun2SocksTCPSocket *)socket;

- (void)socketDidReset:(YYTun2SocksTCPSocket *)socket;

- (void)socketDidAbort:(YYTun2SocksTCPSocket *)socket;

- (void)socketDidClose:(YYTun2SocksTCPSocket *)socket;

- (void)socket:(YYTun2SocksTCPSocket *)socket didReadData:(NSData *)data;

- (void)socket:(YYTun2SocksTCPSocket *)socket didWriteDataOfLength:(NSUInteger)length;

@end
