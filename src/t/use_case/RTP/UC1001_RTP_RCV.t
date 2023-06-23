BEGIN {
  use Cwd;
  push @INC, getcwd.'/t';
  #$ENV{DBI_TRACE}=1;
}

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use JSON;


exit main( @ARGV );

sub main {
  my @args  = @_;

  my $t = Test::Mojo->new('MastroManucci');

  if (@args) {
    for my $name (@args) {
      die "No test method test_$name\n"
        unless my $func = __PACKAGE__->can( 'test_' . $name );
      $func->($t);
    }
    done_testing;
    return 0;
  }

  test_create_subacct($t);
  test_rtp_use_case($t);

  done_testing;
  return 0;
}

sub test_create_subacct {

  my $t = shift;

  my %headers = (
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
  );

  my %subacct = (
    foo => 'bar',
  );

  my $reference = int(rand(1000000));

  # OpenAPI Schema Validations
  $t->post_ok('/subacct' =>  \%headers => json => \%subacct)
    ->status_is(400)->content_like(qr/errors.*Missing property.*/i);

  # Wrong account
  %subacct = (
    reference => $reference,
    type      => 'CREDITOR',
    name      => 'Every Day Checking Account',
    link      => '{ system: "customers", id: 498764 }',
    account   => '9', #wrong
  );

  $t->post_ok('/subacct' => \%headers => json => \%subacct)
    ->status_is(400)->content_like(qr/does not exist in coa/i);

  # Wrong type for CREDITOR
  $subacct{account} = '1010';
  $t->post_ok('/subacct' => \%headers => json => \%subacct)
    ->status_is(400)->content_like(qr/must be of type liability/i);

  $subacct{account} = '2010';
  $t->post_ok('/subacct' => \%headers => json => \%subacct)
    ->status_is(201)
    ->json_is('/account' => $subacct{account})
    ->json_has('/id')
    ->json_is('/name' => $subacct{name})
    ->json_is('/reference' => $subacct{reference})
    ->json_is('/type' => $subacct{type})
    ->json_hasnt('/subType');

}

###############################################
##          USE CASE EXAMPLE
## U.S. Bank receiving RTP funds for a user
###############################################


sub test_rtp_use_case {
  my $t = shift;

  my %headers = (
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
  );

  my %subacct = (
    foo => 'bar',
  );

  my $customer_reference = int(rand(1000000));

  diag('Setup Step 1: Create the customer');

  my %customer = (
    reference => $customer_reference,
    type      => 'CREDITOR',
    subType   => 'CUSTOMER',
    name      => 'Every Day Checking Account',
    link      => '{ system: "customers", id: 498764 }',
    account   => '2010' #AP
  );

  diag('POST data for Customer:'.encode_json(\%customer));

  $t->post_ok('/subacct' => \%headers => json => \%customer)
    ->status_is(201)
    ->json_is('/account' => $customer{account})
    ->json_has('/id')
    ->json_is('/name' => $customer{name})
    ->json_is('/reference' => $customer{reference})
    ->json_is('/type' => $customer{type})
    ->json_is('/subType' => $customer{subType});


  diag('Setup Step 2: Create the partner');

  my $partner_reference = int(rand(1000000));

  my %partner = (
    reference => $partner_reference,
    type      => 'DEBTOR',
    subType   => 'PARTNER',
    name      => 'Citibank',
    link      => '{ system: "partners", id: 1000001 }',
    account   => '1010' #AR
  );

  $t->post_ok('/subacct' => \%headers => json => \%partner)
    ->status_is(201)
    ->json_is('/account' => $partner{account})
    ->json_has('/id')
    ->json_is('/name' => $partner{name})
    ->json_is('/reference' => $partner{reference})
    ->json_is('/type' => $partner{type})
    ->json_is('/subType' => $partner{subType});

  diag('POST data for Partner:'.encode_json(\%partner));


  ### RTP MONEY RECEIVE WORKFLOW ###

  diag('RTP RX Example Step 1: Create the payment order');

  my $customer_subacct_uuid = $t->app->pg->db->select('subacct',undef,{reference => $customer_reference})->hash->{uid};
  my $tch_subacct_uuid = $t->app->pg->db->select('subacct',undef,{reference => $partner_reference})->hash->{uid};


  my $order_reference = int(rand(1000000));

  my %rtp_rx_tx = (
    subacctId    => $tch_subacct_uuid, #TCH sets AR for this transaction
    #reference => '520000421074253', # <--- I don'' think we should enforce uniqueness (we actually can't)
    reference => $order_reference,
    description => 'RTP RX TO: BODDEN MARY R 1011017',
    subType   => 'ORDER',    # orders don't create GL entries
    link      => to_json({ foo => 'bar' }),
    dataIn    => &sampleDataIn,
    lineItems => [
      {subacctId => $customer_subacct_uuid, amount => 524.7}
    ]
  );

  diag('POST data for order:'.encode_json(\%rtp_rx_tx));


  $t->post_ok('/transaction' => \%headers => json => \%rtp_rx_tx)
    ->status_is(201)
    ->json_has('/id')
    ->json_is('/description' => $rtp_rx_tx{description})
    ->json_is('/lineItems/0/account' => $customer{account})
    ->json_is('/lineItems/0/amount' => $rtp_rx_tx{lineItems}->[0]->{amount})
    ->json_is('/lineItems/0/subacctId' => $customer_subacct_uuid)
    ->json_has('/postDate')
    ->json_is('/reference' => $rtp_rx_tx{reference})
    ->json_is('/amount' => $rtp_rx_tx{lineItems}->[0]->{amount})
    ->json_is('/state' => 'CREATED')
    ->json_is('/type' => 'AR')
    ->json_is('/subType' => 'ORDER');

  my $order_id = $t->tx->res->json->{id};

  #TODO: these are just status changes on the ORDER (pending status API)
  diag('TODO: RTP RX Example Step 2: Verify Account');
  diag('TODO: RTP RX Example Step 3: Account Verified');

  diag('RTP RX Example Step 4: Pay customer, issue invoice, and ledger journals');

  $t->post_ok(qq|/order/$order_id/invoice| => \%headers => json => { })
    ->status_is(201)
    ->json_has('/id')
    ->json_is('/description' => $rtp_rx_tx{description})
    ->json_is('/lineItems/0/account' => $customer{account})
    ->json_is('/lineItems/0/amount' => $rtp_rx_tx{lineItems}->[0]->{amount})
    ->json_is('/lineItems/0/subacctId' => $customer_subacct_uuid)
    ->json_has('/postDate')
    ->json_is('/reference' => $rtp_rx_tx{reference})
    ->json_is('/amount' => $rtp_rx_tx{lineItems}->[0]->{amount})
    ->json_is('/state' => 'IN_PROGRESS')
    ->json_is('/type' => 'AR')
    ->json_is('/subType' => 'INVOICE');


}

sub test_rtp_simple_load {
  my $t = shift;

  my $start = time();
  my $cycles = 5000;
  for(my $i=0; $i<$cycles; $i++){
    &test_rtp_use_case($t);
  }
  my $end = time();
  my $runtime = sprintf("%.16s", $end - $start);
  diag(qq|Load test of $cycles complete RTP cyccles in $runtime seconds.|);
}


sub sampleDataIn {
  my $sample_rtp_data = {
    Entity  => {
      'online -dollar -transaction' => {
        DPRetAcctWithholdingAmt     => 0,
        TxnSecurityInd              => 0,
        DPTxnCde                    => 70,
        DPAcctNbr                   => 32958936,
        DPTxnSrcCde                 => 521,
        GLBranch                    => 0,
        DPCat                       => "D",
        DPLogTyp                    => "L",
        GLAcctType                  => 0,
        DPGLAcctNbr                 => 1011017,
        DPRetAcctWithholdingTxnCde  => 0,
        DPDolrTxnOrigTxnCde         => 0,
        DPHiddenSrcCde              => 521,
        DPGLCstCntr                 => 55,
        ShrtNme                     => "BODDEN MARY R",
        DPDolrSrlNbr                => 0,
        DPDolrTxnAmt                => 524.7,
        DPTxnCntlNbr                => 520000421074253
      }
    },
    Metadata  => {
      MsgLst => [
        {
          Type     => "Informational Message",
          Text     => "Success",
          Severity => "Info",
          Code     => "0"
        },
        {
          Type     => "Informational Message",
          Text     => "DPOD031-ACCOUNT HAS DIRECT DEPOSIT.",
          Severity => "Info", Code => "D600031"
        },
        {
          Type     => "Informational Message",
          Text     => "RTP DEPOSIT PROCESSED MESSAGES ARE ALERTS BODDEN MARY R",
          Severity => "Info",
          Code     => "D60"
        }
      ]
    },
    namespace               => "nsCorePost",
    messageId               => "M20210421211370529T1BPFN11170800133",
    txId                    => "20210421021000021P1BRJPM00020005928",
    bankId                  => "211370529T1",
    executionId             => "15DF2764-A1DC-4CDE-A263-B7A1DC2A23CB",
    customerAcctToken       => "C2C112906EBFE53EBCB78868A5E792C9",
    timezoneBank            => "UTC-4",
    timezoneTch             => "UTC-4",
    timestampUtcDisplay     => "2021-04-21T12:42:47:999",
    timestampUtcDisplayTch  => "2021-04-21T08:42:47:999",
    timestampUtcDisplayBank => "2021-04-21T08:42:47:999",
    trxAmount               => "000000052470",
    trxAmountDec            => 524.7,
    timestampUtcTch         => 1619023367999,
    timestampUtcBank        => 1619023367999,
    timestampUtc            => 1619008967999,
    nsTchReceive            => {
      meta   => {
        messageIdPath     => "payload.msgId",
        messageTypePath   => "payload.transType",
        txIdPath          => "payload.txId",
        txAmtPath         => "payload.transAmount",
        status            => "",
        keyPathPrefix     => "AVIDIA",
        protectedPathsDef => [
          "payload.recipient.accNo",
          "payload.recipient.email",
          "payload.recipient.birth_info.dateOfBirth",
          "payload.sender.accNo",
          "payload.sender.email",
          "payload.sender.birth_info.dateOfBirth"
        ],
        queueData  => {
          sqsQueueName        => "",
          sqsQueueGroupName   => "",
          queueDedupMessageId => "",
          queueSequenceNumber => "",
          messageSize         => "",
          timestampUtc        => ""
        },
        stateMachine => {
          stateMachineArn  => "arn:aws:states:us-east-2:208539946927:stateMachine:TCH-Receive-Credit-StateMachine",
          stateMachineName => "TCH-Receive-Credit-StateMachine"
        }
      },
      body => {
        meta => {
          messageId                        => "eb1d463d-e1b3-41b8-9141-3275c7b08ace",
          receiptHandle                    => "AQEBEs4Sw5iGwJL0bX960w6qQRwcz6dGaJb4reZhd+qEGAcFEL/1JDrzCwPZpV87Uiv/q5911ciPFK+w2knJjUFspqKiMskgP0SXYh//17yXGkUOicadQFutg9kvgrPh12gqIewvz873lA1ofdNE6wZLY2xtuEdffcaynW1eODJHM8eBT9UwTl+h2O/hqOXZoHvjVc7tZmmlPcnAiU7T4V5+Xkxh6haB0skk6dPkce2oUSc4rivMPCNABytFAK6/ffHUE+JT3L0fo+vFO5t0F4bhVg==",
          messageGroupId                   => "c2c112906ebfe53ebcb78868a5e792c9",
          approximateReceiveCount          => "1",
          approximateFirstReceiveTimestamp => "1619008952024",
          messageDeduplicationId           => "20210421124231984",
          senderId                         => "AROATBDPTB6XU4M6SIPBE:i-0043d9bd57c4753f0",
          sentTimestamp                    => "1619008952024",
          sequenceNumber                   => "92648186660265902336"
        },
        payload => {
          msgId             => "M20210421021000021P1BJPM00020005927",
          creDtTm           => "2021-04-21T08:42:29",
          routingEntity     => "TCH",
          transType         => "CDT",
          transAmount       => "000000052470",
          transCountryCode  => "840",
          currency          => "USD",
          rrn               => "817010004231",
          refNbr            => "004231",
          dateAndTime       => "0321004231",
          localDate         => "0321",
          localTime         => "004231",
          recipient         => {
            nameOnAccount => "Mary Bodden",
            firstName     => "Mary Bodden",
            lastName      => "Mary Bodden",
            accNo         => "AVIDIA/A29482DE-65D9-45D8-95C1-F390A5AB52EF"
          },
          sender            => {
            nameOnAccount => "VENMO",
            firstName     => "VENMO",
            lastName      => "VENMO",
            phone         => "",
            email         => "",
            accNo         => "AVIDIA/DE730421-7933-40C6-9E6B-658A92E9C081",
            address       => {
              line2              => "95 Morton St",
              city               => "New York City",
              countrySubdivision => "00",
              postalCode         => "10014",
              country            => "US"
            }
          },
          settlement_amount => "000000052470",
          settlement_date   => "2021-04-21",
          instrId           => "20210421021000021P1BRJPM00020005928",
          endToEndId        => "21042112198329323",
          txId              => "20210421021000021P1BRJPM00020005928",
          instgId           => "021000021",
          instdId           => "211370529",
          dbtrId            => "021000021",
          cdtrId            => "211370529",
          duplicate         => "NO",
          instrForCdtrAgt   => [],
          lclInstrm         => "STANDARD",
          ctgyPurp          => "BUSINESS",
          clrSysRef         => "001"
        }
      },
      status => "COMPLETE"
    }
  };

  return encode_json($sample_rtp_data);

}

