//
//  YYTun2SocksIPStack.m
//  YYTun2Socks
//
//  Created by Hmyy on 2017/9/20.
//
//

#import "YYTun2SocksIPStack.h"
#import "YYTun2SocksTCPSocket.h"
#include "lwip/init.h"
#include "lwip/tcp.h"
#include "lwip/timeouts.h"
#include "lwip/netif.h"
#include <sys/socket.h>

@interface YYTun2SocksIPStack ()

@property (nonatomic, weak) id<YYTun2SocksIPStackDelegate> delegate;
@property (nonatomic, copy) outputPacketCallback outputCallback;

@property (nonatomic, strong) dispatch_queue_t processQueue;

@property (nonatomic, strong) dispatch_source_t timer;

@property (nonatomic, assign) struct tcp_pcb *listenPcb;

@property (nonatomic, assign) struct netif *defaultInterface;

@end

@implementation YYTun2SocksIPStack

/** Function prototype for tcp accept callback functions. Called when a new
 * connection can be accepted on a listening pcb.
 *
 * @param arg Additional argument to pass to the callback function (@see tcp_arg())
 * @param newpcb The new connection pcb
 * @param err An error code if there has been an error accepting.
 *            Only return ERR_ABRT if you have called tcp_abort from within the
 *            callback function!
 */
static err_t tcpAcceptCallback(void *arg, struct tcp_pcb *newpcb, err_t err)
{
    return [[YYTun2SocksIPStack defaultTun2SocksIPStack] didAcceptTcpPcb:newpcb error:err];
}

/** Function prototype for netif->output functions. Called by lwIP when a packet
 * shall be sent. For ethernet netif, set this to 'etharp_output' and set
 * 'linkoutput'.
 *
 * @param netif The netif which shall send a packet
 * @param p The packet to send (p->payload points to IP header)
 * @param ipaddr The IP address to which the packet shall be sent
 */
static err_t packetOutput(struct netif *netif, struct pbuf *p,
const ip4_addr_t *ipaddr)
{
    [[YYTun2SocksIPStack defaultTun2SocksIPStack] sendOutPacket:p];
    return ERR_OK;
}

static YYTun2SocksIPStack *_instance = nil;

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}

- (instancetype)init
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super init];
        _instance.processQueue = dispatch_queue_create("tun2socks.IPStack.queue", DISPATCH_QUEUE_SERIAL);
        [self setup];
    });
    return _instance;
}

- (void)setup
{
    lwip_init();
    
    self.listenPcb = tcp_new();
    tcp_bind(self.listenPcb, IP_ADDR_ANY, 0);
    self.listenPcb = tcp_listen_with_backlog(self.listenPcb, TCP_DEFAULT_LISTEN_BACKLOG);
    tcp_accept(self.listenPcb, tcpAcceptCallback);
    
    self.defaultInterface = netif_list;
    netif_set_default(self.defaultInterface);
    self.defaultInterface->output = packetOutput;
}

+(instancetype)defaultTun2SocksIPStack
{
    return [[self alloc] init];
}

- (void)setDelegate:(id<YYTun2SocksIPStackDelegate>)delegate
{
    if (delegate != _delegate)
    {
        _delegate = delegate;
    }
}

- (void)setOutputCallback:(outputPacketCallback)outputCallback
{
    self.outputCallback = [outputCallback copy];
}

- (void)checkTimeouts
{
    sys_check_timeouts();
}

- (void)restartTimeouts
{
    sys_restart_timeouts();
}

- (void)suspendTimer
{
    self.timer = nil;
}

- (void)resumeTimer
{
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.processQueue);
    // note the default tcp_tmr interval is 250 ms.
    uint64_t defaultInterval = 250;
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, defaultInterval * NSEC_PER_MSEC, 1 * NSEC_PER_MSEC);
    @weakify(self);
    dispatch_source_set_event_handler(self.timer, ^{
        @strongify(self);
        [self checkTimeouts];
    });
    [self restartTimeouts];
    dispatch_resume(self.timer);
    
}

- (void)sendOutPacket:(struct pbuf *)pbuf
{
    uint16_t totalLength = pbuf->tot_len;
    uint8_t *bytes = malloc(sizeof(uint8_t) * totalLength);
    pbuf_copy_partial(pbuf, bytes, totalLength, 0);
    NSData *packet = [[NSData alloc] initWithBytesNoCopy:bytes length:totalLength freeWhenDone:YES];
    if (self.outputCallback != nil)
    {
        self.outputCallback(packet, AF_INET);
    }
}

- (void)receivedPacket:(NSData *)packet
{
    assert(packet.length <= UINT16_MAX);
    struct pbuf *packetBuffer = pbuf_alloc(PBUF_RAW, packet.length, PBUF_RAM);
    packetBuffer->payload = (void *)[packet bytes];
    
    // The `netif->input()` should be ip_input(). According to the docs of lwip, we do not pass packets into the `ip_input()` function directly.
    self.defaultInterface->input(packetBuffer,self.defaultInterface);
    
}

- (err_t)didAcceptTcpPcb:(struct tcp_pcb *)pcb error:(err_t)err
{
    tcp_backlog_accepted(pcb);
    if (nil != self.delegate && [self.delegate respondsToSelector:@selector(didAcceptTCPSocket:)])
    {
#warning todo
        YYTun2SocksTCPSocket *socket = nil;
        [self.delegate didAcceptTCPSocket:socket];
    }
    return err;
}

@end
