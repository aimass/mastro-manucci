# EXAMPLE USE IN REAL TIME PAYMENTS (RTP)

## RTP Receive Example ##

In RTP Receive there are generally 4 steps involved that happen in a span of maximum 5 seconds:

1. RTP Money Receive Message
1. Account Verification
    1. Exception: Account not valid
1. Respond RTP Receive OK or FAIL
1. Credit the Customer
1. Offline/batch reconciliation

For Moonshot Ledger this is considered a long 

### Accounting for RTP Rx ###

1. RTP Money Receive Message
    1. An AR Note is created vendor = TCH with the amount of Txn state = RTPRCV
    1. An AP Doc is created with customer = cacctnum and the amount of the Txn state = RTPRCV
    1. Journal Entries for BOTH AP and AR docs
        1. Credit to account: bar
        1. Debit to account: foo
    
1. Account Verification
    1. Changes state of AR doc to = VERIFIED, stores data in state table
    1. Changes state of AP doc to  = VERIFIED, stores data in state table
    1. Exception:
        1. Need to reverse AP and AR status = VERIF_FAIL
1. Respond to TCH
    1. IF state = VERIFIED
        1. Changes state of AR doc to = RTPRESPOK, stores data in state table
        1. Changes state of AP doc to  = RTPRESPOK, stores data in state table
        1. Respond OK to TCH
    2. ELSE
        1. Changes state of AR doc to = CANCEL, stores data in state table
        1. Changes state of AP doc to  = CANCEL, stores data in state table
        1. Respond FAIL to TCH
1. Credit the Customer
    1. Journal Entries for ONLY AP Doc
        1. Credit Account: foo
        2. Debit Account: bar
    1. Changes state of AR doc to = PENDING, stores data in state table
    1. Changes state of AP doc to  = CLOSED, stores data in state table
    
1. Sometime in the future someone (or some system) reconciles and:
    1. Journal Entries for ONLY AR Doc
        1. Credit Account: foo
        2. Debit Account: bar
    1. Changes state of AR doc to = CLOSED, stores data in state table
     

