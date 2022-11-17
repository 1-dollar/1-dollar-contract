module oneDollar_v0_0::onedollar_v0{
    use std::string::String as String;
    use std::error;
    use std::option;
    use std::bcs;
    use std::signer;
    use std::debug;
    use aptos_framework::resource_account;
    use std::option::Option as Option;
    use aptos_std::event as event;
    use aptos_std::table;
    use std::vector;
    use aptos_token::token;
    use aptos_token::token::Token as Token;
    use aptos_token::token::TokenId;
    //use std::vector as vector;
        use aptos_framework::coin::{Self, Coin };
    use std::signer::address_of as address_of;
    use aptos_std::simple_map as map;
    use aptos_framework::timestamp;
    //use aptos_framework::coin;
    use aptos_framework::account;
    //use aptos_framework::aptos_coin;
    //use aptos_framework::coin::Coin as Coin;

    use oneDollar_v0_0::random_number::rand_u64_range;

    const ONEDOLLAR_ADMIN : address = @oneDollar_v0_0;
    const STD_ADDRESS : address = @std;
  
    const DOLLAR_ONLY_ADMIN:u64 = 1;

    const ONEDOLLARSMAP_NOT_FOUND:u64 = 2;
    
    const ONEDOLLAR_NOT_FOUND:u64 = 3;

    const SALE_NOT_ACTIVITY:u64 = 4;

    const TICKECTS_INSUFFICIENT:u64 = 5;

    const TICKETS_NOT_FOUND:u64 = 6;

    const ONLY_WINNER:u64 = 7;

    const WITHDRAW_DENY:u64 = 8;

    const SECRET_NUM_INVALID:u64 = 9;

    const CLAIM_SECRET_DENY:u64 = 10;

    const UNUSED:u64 = 0;
    const CLAIMED:u64 = 1;
    const REFUNDED:u64 = 2;

    struct Creator has store,key {
        address_map: map::SimpleMap<address,bool>
    }
    struct ResourceData has key {
        resource_signer_cap: account::SignerCapability,
    }

    public entry fun init(account: &signer) {
        let (lp_acc, resource_signer_cap) =
            account::create_resource_account(account,  b"1dollar");
        //resource_account::create_resource_account(account,vector::empty(),vector::empty());
        //let resource_signer_cap = resource_account::retrieve_resource_account_cap(account, ONEDOLLAR_ADMIN);
        move_to(account, ResourceData {
            resource_signer_cap,
        });
    }
    fun resource_address_signer():signer acquires ResourceData  {
        let module_data = borrow_global_mut<ResourceData>(ONEDOLLAR_ADMIN);
        let resource_signer = account::create_signer_with_capability(&module_data.resource_signer_cap);
        resource_signer
    }

    struct OneDollarsTokenCollection<phantom FundCoin:key> has key,store {
        //HashMap<onedollar_id,onedollar>
        onedollars_map: map::SimpleMap<u64,OneDollarToken<FundCoin>>,
        create_event:event::EventHandle<CreateOneDollarEvent>
    }

    struct OneDollarToken<phantom FundCoin:key> has store,key {
        description:String,
        total_tickets:u64,
        ticket_value:u64,
        selled_tickets:u64,
        create_time:u64,
        delay_time:u64,
        sell_out_time:Option<u64>,
        is_claimed:bool,
        is_withdrawed:bool,
        selling_time:u64,
        lucky_code:Option<u64>,
        winner:Option<address>,
        reward: TokenId,
        reward_val:u64,
        fund: Coin<FundCoin>,
        creator:address,
        sell_tickets_event:event::EventHandle<SellTicketsEvent>
    }


    struct OneDollarsCoinCollection<phantom RewardCoin:key,phantom FundCoin:key> has key,store {
        //HashMap<onedollar_id,onedollar>
        onedollars_map: map::SimpleMap<u64,OneDollarCoin<RewardCoin,FundCoin>>,
        create_event:event::EventHandle<CreateOneDollarEvent>
    }

    struct OneDollarCoin<phantom RewardCoin:key,phantom FundCoin:key> has store,key {
        description:String,
        total_tickets:u64,
        ticket_value:u64,
        selled_tickets:u64,
        create_time:u64,
        delay_time:u64,
        sell_out_time:Option<u64>,
        is_claimed:bool,
        is_withdrawed:bool,
        selling_time:u64,
        lucky_code:Option<u64>,
        winner:Option<address>,
        reward: Coin<RewardCoin>,
        reward_val:u64,
        fund: Coin<FundCoin>,
        //secret_number:SecetNumber,
        creator:address,
        sell_tickets_event:event::EventHandle<SellTicketsEvent>
    }

    struct OneDollarTicketsCollection has store,key {
        onedollar_tickets_map: map::SimpleMap<u64,OneDollarTicket>,
    }


    struct OneDollarStateList has key{
        state_table: table::Table<u64,OneDollarState>
    }
    struct OneDollarState has store {
        deadline:u64,
        success:bool
    }

    struct SelledAllTicketsTable has key{
        selled_tickets: table::Table<u64,SelledTicketsTable>,

    }

    struct TransferTicketsEvent has store,drop,copy{
        from:address,
        to:address,
        onedollar_id:u64,
        ticket_code:u64,
        timestamp:u64
    }


    struct SelledTicketsTable has store{
        lucky_code:Option<u64>,
        selled_tickets: map::SimpleMap<u64,address>,
        transfer_tickets_event: event::EventHandle<TransferTicketsEvent>,
    }

    struct OneDollarTicket has store,key {
        tickets: vector<TicketInfo>,
    }
    struct TicketInfo has store{
        ticket_code: u64,
        timestamp:u64,
        state:u64
    }

    public entry fun resgister_ticket(signer:&signer){
        if(!exists<OneDollarTicketsCollection>(address_of(signer))){
            move_to(
                signer,
                OneDollarTicketsCollection{
                    onedollar_tickets_map: map::create<u64,OneDollarTicket>()
                }
            );
        };
    }
    
    public entry fun transfer_all_tickets(signer:&signer,to:address,onedollar_id:u64)acquires OneDollarTicketsCollection,SelledAllTicketsTable,OneDollarStateList{
        transfer_deny(onedollar_id);
        let tickets = extract_all_ticket(signer,onedollar_id);
        merge_all_ticket(to,onedollar_id,address_of(signer),tickets);
    }

    public fun extract_all_ticket(signer:&signer,onedollar_id:u64):vector<TicketInfo> acquires OneDollarTicketsCollection{
        assert!(exists<OneDollarTicketsCollection>(address_of(signer)),error::not_found(28));
        let from_tickets_map = borrow_global_mut<OneDollarTicketsCollection>(address_of(signer));
        assert!(map::contains_key(&from_tickets_map.onedollar_tickets_map,&onedollar_id),error::not_found(30));
        let tickets = map::borrow_mut(&mut from_tickets_map.onedollar_tickets_map,&onedollar_id);
        remove_all_ticket_internal(tickets)
    }
    public fun merge_all_ticket(to:address,onedollar_id:u64,from:address,tickets:vector<TicketInfo>)acquires OneDollarTicketsCollection,SelledAllTicketsTable{
        assert!(exists<OneDollarTicketsCollection>(to),error::not_found(29));
        let to_tickets_map = borrow_global_mut<OneDollarTicketsCollection>(to);
        if(!map::contains_key(&to_tickets_map.onedollar_tickets_map,&onedollar_id)){
            map::add(&mut to_tickets_map.onedollar_tickets_map,onedollar_id,OneDollarTicket{tickets:vector::empty()});
        };
        let to_tickets = map::borrow_mut(&mut to_tickets_map.onedollar_tickets_map,&onedollar_id);
        let index = 0;
        let len = vector::length(&tickets);
        while(index < len){
            set_ticket_holder(onedollar_id,*&vector::borrow(&tickets,index).ticket_code,from,to);
            index = index + 1;

        };
        add_all_ticket_internal(to_tickets,tickets);
    }


    public entry fun transfer_ticket(signer:&signer,to:address,onedollar_id:u64,ticket_code:u64)acquires OneDollarTicketsCollection,SelledAllTicketsTable,OneDollarStateList{
        transfer_deny(onedollar_id);
        let ticket = extract_ticket(signer,onedollar_id,ticket_code);
        merge_ticket(to,onedollar_id,ticket);
        set_ticket_holder(onedollar_id,ticket_code,address_of(signer),to);
    }

    public fun extract_ticket(signer:&signer,onedollar_id:u64,ticket_code:u64):TicketInfo acquires OneDollarTicketsCollection{
        assert!(exists<OneDollarTicketsCollection>(address_of(signer)),error::not_found(28));
        let from_tickets_map = borrow_global_mut<OneDollarTicketsCollection>(address_of(signer));
        assert!(map::contains_key(&from_tickets_map.onedollar_tickets_map,&onedollar_id),error::not_found(30));
        let tickets = map::borrow_mut(&mut from_tickets_map.onedollar_tickets_map,&onedollar_id);
        remove_ticket_internal(tickets,ticket_code)
    }




    public fun merge_ticket(to:address,onedollar_id:u64,ticket:TicketInfo)acquires OneDollarTicketsCollection{
        assert!(exists<OneDollarTicketsCollection>(to),error::not_found(29));
        let to_tickets_map = borrow_global_mut<OneDollarTicketsCollection>(to);
        if(!map::contains_key(&to_tickets_map.onedollar_tickets_map,&onedollar_id)){
            map::add(&mut to_tickets_map.onedollar_tickets_map,onedollar_id,OneDollarTicket{tickets:vector::empty()});
        };
        let to_tickets = map::borrow_mut(&mut to_tickets_map.onedollar_tickets_map,&onedollar_id);
        add_ticket_internal(to_tickets,ticket);
    }

    fun refund_val(tickets:&OneDollarTicket):u64{
        let len = vector::length(&tickets.tickets);
        let index = 0;
        let val = 0;
        while(index < len){
            if(vector::borrow(&tickets.tickets,index).state == UNUSED){
                val = val + 1;
            };
            index = index +1;
        };
        assert!(val>0,error::unavailable(446));
        val
    }

    fun refund_state_internal(tickets:&mut OneDollarTicket){
        let len = vector::length(&tickets.tickets);
        let index = 0;
        while(index < len){
            vector::borrow_mut(&mut tickets.tickets,index).state = REFUNDED;
            index = index +1;
        };
    }

    fun change_state_internal(tickets:&mut OneDollarTicket,code:u64,state:u64){
        let len = vector::length(&tickets.tickets);
        let index = 0;
        while(index < len){
            if(vector::borrow(&tickets.tickets,index).ticket_code == code){
                vector::borrow_mut(&mut tickets.tickets,index).state = state;
            };
            index = index +1;
        };
    }

    fun contain_ticket(tickets:&OneDollarTicket,code:u64): bool{
        let len = vector::length(&tickets.tickets);
        let index = 0;
        while(index < len){
            if(vector::borrow(&tickets.tickets,index).ticket_code==code){
                return true
            };
            index = index +1;
        };
        false
    }
    fun add_ticket_internal(tickets:&mut OneDollarTicket,ticket:TicketInfo){
        vector::push_back(&mut tickets.tickets,ticket);
    }
    fun add_all_ticket_internal(tickets:&mut OneDollarTicket,new_tickets:vector<TicketInfo>){
        vector::append(&mut tickets.tickets,new_tickets);
    }

    fun remove_ticket_internal(tickets:&mut OneDollarTicket,code:u64):TicketInfo{
        let len = vector::length(&tickets.tickets);
        let find = false;
        let target = 0;
        let index = 0;
        while(index < len && find==false) {
            if(vector::borrow(&tickets.tickets,index).ticket_code==code){
                target = index;
                find = true;
            };
            index = index +1;
        };
        assert!(find,error::not_found(44));
        vector::remove(&mut tickets.tickets,target)
    }
        
    fun remove_all_ticket_internal(tickets:&mut OneDollarTicket):vector<TicketInfo>{
        let all_ticket = vector::empty();
        while(vector::length(&tickets.tickets)>0){
            let x = vector::pop_back(&mut tickets.tickets);
            vector::push_back(&mut all_ticket,x);
        };
        all_ticket
    }


    struct CreateOneDollarEvent has store,drop,copy {
        creator:address,
        onedollar_id:u64
    }

    struct SellTicketsEvent has store,drop,copy {
        onedollar_id:u64,
        amount: u64,
        account: address, 
        timestamp:u64
    }

    struct BuyTicketsEvent has store,drop,copy{
        amount: u64,
        onedollar_id:u64, 
        time:u64
    }


     public entry fun create_reward_token<FundCoin:key>(
        signer:&signer,
        description: String,
        id:u64,
        token_amount: u64,
        total_tickets:u64,
        ticket_value:u64,
        selling_time:u64,
        delay_time:u64,
        token_creator:address,
        collection:String,
        name:String,
        property_version:u64,
        //secret_number:u64
        )acquires OneDollarsTokenCollection,Creator,OneDollarStateList,SelledAllTicketsTable,ResourceData{
            let tokenId = token::create_token_id_raw(token_creator,collection,name,property_version);
            //let resource_addr = aptos_framework::account::create_resource_address(&ONEDOLLAR_ADMIN, b"");
            token::direct_transfer(signer,&resource_address_signer(),tokenId,token_amount);
            //let token = token::withdraw_token(signer,tokenId,token_amount);
            let buy_coin = coin::withdraw<FundCoin>(signer,0);
            create_reward_token_internal<FundCoin>(
                description,
                signer,
                id,
                tokenId,
                token_amount,
                buy_coin,
                total_tickets,
                ticket_value,
                selling_time, 
                //secret_number, 
                delay_time
            );
        }



     public entry fun create_reward_coin<RewardCoin:key,FundCoin:key>(
        signer:&signer,
        description: String,
        id:u64,
        coin_val: u64,
        total_tickets:u64,
        ticket_value:u64,
        selling_time:u64,
        delay_time:u64,
        //secret_number:u64
        )acquires OneDollarsCoinCollection,Creator,OneDollarStateList,SelledAllTicketsTable{
            let reward_coin = coin::withdraw<RewardCoin>(signer,coin_val);
            let buy_coin = coin::withdraw<FundCoin>(signer,0);
            create_reward_internal<RewardCoin,FundCoin>(
                description,
                signer,
                id,
                reward_coin,
                coin_val,
                buy_coin,
                total_tickets,
                ticket_value,
                selling_time, 
                //secret_number, 
                delay_time
            );
        }

        public fun create_reward_token_internal<FundCoin:key>(        
            description: String,
            signer:&signer,
            id:u64,
            tokenId: TokenId,
            token_amount:u64,
            fund_coin:Coin<FundCoin>,
            total_tickets:u64,
            ticket_value:u64,
            selling_time:u64,
        //secret_number:u64,
            delay_time:u64
        )acquires OneDollarsTokenCollection,Creator,OneDollarStateList,SelledAllTicketsTable{
        
        assert!(is_creator(address_of(signer)), error::unauthenticated(DOLLAR_ONLY_ADMIN));
        
        if(!exists<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN)){
            move_to(
                signer,
                OneDollarsTokenCollection{
                    onedollars_map: map::create<u64,OneDollarToken<FundCoin>>(),
                    create_event:  account::new_event_handle<CreateOneDollarEvent>(signer),
                }
            );
        };

        if(!exists<SelledAllTicketsTable>(ONEDOLLAR_ADMIN)){
            move_to(
                signer,
                SelledAllTicketsTable{
                    selled_tickets: table::new<u64,SelledTicketsTable>(),
                }
            );
        };
        if(!exists<OneDollarStateList>(ONEDOLLAR_ADMIN)){
            move_to(
                signer,
                OneDollarStateList{
                    state_table: table::new<u64,OneDollarState>()
                }
            );
        };


        let collection = borrow_global_mut<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN);
        let state_list = borrow_global_mut<OneDollarStateList>(ONEDOLLAR_ADMIN);
        let selled_list = borrow_global_mut<SelledAllTicketsTable>(ONEDOLLAR_ADMIN);
        let onedollar_id = id;
        event::emit_event(&mut collection.create_event, CreateOneDollarEvent {
                creator:address_of(signer),
                onedollar_id:onedollar_id
            });
        let time = timestamp::now_seconds();
        //coin::deposit<RewardCoin>(address_of(signer),coin);
        let onedollar = OneDollarToken {
            description:description,
            total_tickets:total_tickets,
            ticket_value:ticket_value,
            selled_tickets:0,
            reward:tokenId,
            reward_val:token_amount,
            is_claimed:false,
            is_withdrawed:false,
            sell_out_time:option::none(),
            create_time: time,
            selling_time:selling_time,
            lucky_code:option::none(),
            winner:option::none(),
            fund:coin::extract<FundCoin>(&mut fund_coin,0),
            delay_time:delay_time,
            creator:address_of(signer),
            sell_tickets_event:account::new_event_handle<SellTicketsEvent>(signer),
        };
        coin::deposit(ONEDOLLAR_ADMIN,fund_coin);
        map::add<u64,OneDollarToken<FundCoin>>(&mut collection.onedollars_map,onedollar_id,onedollar);
        table::add(&mut state_list.state_table,onedollar_id,OneDollarState{
            deadline:time+delay_time+selling_time,
            success:false
        });
        table::add(&mut selled_list.selled_tickets,onedollar_id,SelledTicketsTable{
            lucky_code:option::none(),
            selled_tickets: map::create(),
            transfer_tickets_event: account::new_event_handle<TransferTicketsEvent>(signer),
        })
        }
public fun create_reward_internal<RewardCoin:key,FundCoin:key>(
        description: String,
        signer:&signer,
        id:u64,
        coin: Coin<RewardCoin>,
        coin_val:u64,
        fund_coin:Coin<FundCoin>,
        total_tickets:u64,
        ticket_value:u64,
        selling_time:u64,
        //secret_number:u64,
        delay_time:u64
        )acquires OneDollarsCoinCollection,Creator,OneDollarStateList,SelledAllTicketsTable{
        assert!(is_creator(address_of(signer)), error::unauthenticated(DOLLAR_ONLY_ADMIN));

        if(!exists<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN)){
            move_to(
                signer,
                OneDollarsCoinCollection{
                    onedollars_map: map::create<u64,OneDollarCoin<RewardCoin,FundCoin>>(),
                    create_event:  account::new_event_handle<CreateOneDollarEvent>(signer),
                }
            );
        };

        if(!exists<SelledAllTicketsTable>(ONEDOLLAR_ADMIN)){
            move_to(
                signer,
                SelledAllTicketsTable{
                    selled_tickets: table::new<u64,SelledTicketsTable>(),
                }
            );
        };
        if(!exists<OneDollarStateList>(ONEDOLLAR_ADMIN)){
            move_to(
                signer,
                OneDollarStateList{
                    state_table: table::new<u64,OneDollarState>()
                }
            );
        };


        let collection = borrow_global_mut<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN);
        let state_list = borrow_global_mut<OneDollarStateList>(ONEDOLLAR_ADMIN);
        let selled_list = borrow_global_mut<SelledAllTicketsTable>(ONEDOLLAR_ADMIN);
        let onedollar_id = id;
        event::emit_event(&mut collection.create_event, CreateOneDollarEvent {
                creator:address_of(signer),
                onedollar_id:onedollar_id
            });
        let time = timestamp::now_seconds();
        //coin::deposit<RewardCoin>(address_of(signer),coin);
        let onedollar = OneDollarCoin {
            description:description,
            total_tickets:total_tickets,
            ticket_value:ticket_value,
            selled_tickets:0,
            reward:coin,
            reward_val:coin_val,
            is_claimed:false,
            is_withdrawed:false,
            sell_out_time:option::none(),
            create_time: time,
            selling_time:selling_time,
            lucky_code:option::none(),
            winner:option::none(),
            fund:coin::extract<FundCoin>(&mut fund_coin,0),
            /*secret_number: SecretNumber{
                create_code:secret_number,
                user_code:vector::empty()
            },*/
            delay_time:delay_time,
            creator:address_of(signer),
            sell_tickets_event:account::new_event_handle<SellTicketsEvent>(signer),
        };
        coin::deposit(ONEDOLLAR_ADMIN,fund_coin);
        map::add<u64,OneDollarCoin<RewardCoin,FundCoin>>(&mut collection.onedollars_map,onedollar_id,onedollar);
        table::add(&mut state_list.state_table,onedollar_id,OneDollarState{
            deadline:time+delay_time+selling_time,
            success:false
        });
        table::add(&mut selled_list.selled_tickets,onedollar_id,SelledTicketsTable{
            lucky_code:option::none(),
            selled_tickets: map::create(),
            transfer_tickets_event: account::new_event_handle<TransferTicketsEvent>(signer),
        })

    }

    public entry fun buy_ticket<RewardCoin:key , FundCoin:key>(signer:&signer, onedollar_id:u64, amount:u64) acquires OneDollarsCoinCollection ,OneDollarTicketsCollection,SelledAllTicketsTable,OneDollarStateList{

        buy_ticket_internal<RewardCoin,FundCoin>(signer, onedollar_id, amount);
    }

    public entry fun buy_ticket_token<FundCoin:key>(signer:&signer, onedollar_id:u64, amount:u64) acquires OneDollarsTokenCollection ,OneDollarTicketsCollection,SelledAllTicketsTable,OneDollarStateList{

        buy_ticket_token_internal<FundCoin>(signer, onedollar_id, amount);
    }

    public entry fun register_ticket(signer:&signer){
        if(!exists<OneDollarTicketsCollection>(address_of(signer))){
            move_to(
                signer,
                OneDollarTicketsCollection{
                    onedollar_tickets_map: map::create<u64,OneDollarTicket>()
                }
            );
        }else{
            abort 0
        }
    }

    public fun buy_ticket_token_internal<FundCoin:key>(signer:&signer, onedollar_id:u64,amount:u64) acquires OneDollarsTokenCollection,OneDollarTicketsCollection,SelledAllTicketsTable,OneDollarStateList {
        assert!(exists<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN), error::not_found(ONEDOLLARSMAP_NOT_FOUND));
        let collection = borrow_global_mut<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN);
        assert!(map::contains_key(&mut collection.onedollars_map,&onedollar_id),error::not_found(ONEDOLLAR_NOT_FOUND));
        let onedollar = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);
        assert!(sale_is_activity_token_internal(onedollar),error::unavailable(SALE_NOT_ACTIVITY));
        assert!(sale_is_open_token_internal(onedollar),error::unavailable(SALE_NOT_ACTIVITY));
        let (_,tickets_remain) = tickets_info_token_internal(onedollar);
        assert!(tickets_remain>=amount,error::invalid_argument(TICKECTS_INSUFFICIENT));
        let ticket_val = onedollar.ticket_value;

        let time = timestamp::now_seconds();
        let fund_coin = coin::withdraw<FundCoin>(signer, amount*ticket_val);

        coin::merge<FundCoin>(&mut onedollar.fund,fund_coin);
        //record_user_code_internal<RewardCoin,FundCoin>(onedollar,time);

        event::emit_event(&mut onedollar.sell_tickets_event, SellTicketsEvent {
            onedollar_id:onedollar_id,
            amount: amount,
            account: address_of(signer), 
            timestamp:time
        });
        
        //resigster resource 
        if(!exists<OneDollarTicketsCollection>(address_of(signer))){
            move_to(
                signer,
                OneDollarTicketsCollection{
                    onedollar_tickets_map: map::create<u64,OneDollarTicket>()
                }
            );
        };
        
        
        let tickets = borrow_global_mut<OneDollarTicketsCollection>(address_of(signer));
        if(!map::contains_key<u64,OneDollarTicket>(&tickets.onedollar_tickets_map,&onedollar_id)){
            map::add<u64,OneDollarTicket>(
                &mut tickets.onedollar_tickets_map, 
                onedollar_id,
                OneDollarTicket{
                    tickets: vector::empty<TicketInfo>(),
                }
            )
        };
        let ticket_info = map::borrow_mut<u64,OneDollarTicket>(&mut tickets.onedollar_tickets_map,&onedollar_id);

        let code = onedollar.selled_tickets + 1;

        while(code <= onedollar.selled_tickets+amount){
            add_ticket_internal(ticket_info,TicketInfo{
                ticket_code: code,
                timestamp:time,
                state:UNUSED
            });
            set_ticket_holder(onedollar_id,code,STD_ADDRESS,address_of(signer));
            //map::add<u64,u64>(&mut ticket_info.tickets_code,code,time);
            code=code+1;
        };

        onedollar.selled_tickets = onedollar.selled_tickets + amount;

        if(tickets_remain-amount==0){
            let turnover = coin::extract_all<FundCoin>(&mut onedollar.fund);
            coin::deposit<FundCoin>(ONEDOLLAR_ADMIN,turnover);
            onedollar.sell_out_time = option::some(timestamp::now_seconds());
            let lucky_code = rand_u64_range(&address_of(signer),0,onedollar.total_tickets-1);
            onedollar.lucky_code = option::some(lucky_code);
            onedollar.winner = option::some(get_holder(onedollar_id,lucky_code));
            let states = borrow_global_mut<OneDollarStateList>(ONEDOLLAR_ADMIN);
            let state = table::borrow_mut(&mut states.state_table,onedollar_id);
            state.success = true;
        }
    }

    public fun buy_ticket_internal<RewardCoin:key , FundCoin:key>(signer:&signer, onedollar_id:u64,amount:u64) acquires OneDollarsCoinCollection,OneDollarTicketsCollection,SelledAllTicketsTable,OneDollarStateList {
        //condition
        assert!(exists<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN), error::not_found(ONEDOLLARSMAP_NOT_FOUND));
        let collection = borrow_global_mut<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN);
        assert!(map::contains_key(&mut collection.onedollars_map,&onedollar_id),error::not_found(ONEDOLLAR_NOT_FOUND));
        let onedollar = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);
        assert!(sale_is_activity_internal(onedollar),error::unavailable(SALE_NOT_ACTIVITY));
        assert!(sale_is_open_internal(onedollar),error::unavailable(SALE_NOT_ACTIVITY));
        let (_,tickets_remain) = tickets_info_internal(onedollar);
        assert!(tickets_remain>=amount,error::invalid_argument(TICKECTS_INSUFFICIENT));
        let ticket_val = onedollar.ticket_value;

        let time = timestamp::now_seconds();
        let fund_coin = coin::withdraw<FundCoin>(signer, amount*ticket_val);

        coin::merge<FundCoin>(&mut onedollar.fund,fund_coin);
        //record_user_code_internal<RewardCoin,FundCoin>(onedollar,time);

        event::emit_event(&mut onedollar.sell_tickets_event, SellTicketsEvent {
            onedollar_id:onedollar_id,
            amount: amount,
            account: address_of(signer), 
            timestamp:time
        });
        
        //resigster resource 
        if(!exists<OneDollarTicketsCollection>(address_of(signer))){
            move_to(
                signer,
                OneDollarTicketsCollection{
                    onedollar_tickets_map: map::create<u64,OneDollarTicket>()
                }
            );
        };
        
        if(!coin::is_account_registered<RewardCoin>(address_of(signer))){
            coin::register<RewardCoin>(signer);
        };
        
        
        let tickets = borrow_global_mut<OneDollarTicketsCollection>(address_of(signer));
        if(!map::contains_key<u64,OneDollarTicket>(&tickets.onedollar_tickets_map,&onedollar_id)){
            map::add<u64,OneDollarTicket>(
                &mut tickets.onedollar_tickets_map, 
                onedollar_id,
                OneDollarTicket{
                    tickets: vector::empty<TicketInfo>(),
                }
            )
        };
        let ticket_info = map::borrow_mut<u64,OneDollarTicket>(&mut tickets.onedollar_tickets_map,&onedollar_id);

        let code = onedollar.selled_tickets + 1;

        while(code <= onedollar.selled_tickets+amount){
            add_ticket_internal(ticket_info,TicketInfo{
                ticket_code: code,
                timestamp:time,
                state:UNUSED
            });
            set_ticket_holder(onedollar_id,code,STD_ADDRESS,address_of(signer));
            //map::add<u64,u64>(&mut ticket_info.tickets_code,code,time);
            code=code+1;
        };

        onedollar.selled_tickets = onedollar.selled_tickets + amount;

        if(tickets_remain-amount==0){
            let turnover = coin::extract_all<FundCoin>(&mut onedollar.fund);
            coin::deposit<FundCoin>(ONEDOLLAR_ADMIN,turnover);
            onedollar.sell_out_time = option::some(timestamp::now_seconds());
            //let seed = bcs::to_bytes(&onedollar);
            let lucky_code = rand_u64_range(&address_of(signer),0,onedollar.total_tickets-1);
            onedollar.lucky_code = option::some(lucky_code);
            onedollar.winner = option::some(get_holder(onedollar_id,lucky_code));
            let states = borrow_global_mut<OneDollarStateList>(ONEDOLLAR_ADMIN);
            let state = table::borrow_mut(&mut states.state_table,onedollar_id);
            state.success = true;
        }
    }

    public entry fun claim_and_refund_token<FundCoin:key>(signer:&signer,onedollar_id:u64) acquires OneDollarsTokenCollection, OneDollarTicketsCollection,ResourceData{
        let collection = borrow_global_mut<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN);
        assert!(exists<OneDollarTicketsCollection>(address_of(signer)),error::not_found(TICKETS_NOT_FOUND));
        let tickets_collection = borrow_global_mut<OneDollarTicketsCollection>(address_of(signer));
        assert!(map::contains_key<u64,OneDollarTicket>(&tickets_collection.onedollar_tickets_map,&onedollar_id),error::not_found(TICKETS_NOT_FOUND));
        let tickets = map::borrow_mut<u64,OneDollarTicket>(&mut tickets_collection.onedollar_tickets_map,&onedollar_id);
        //let tickets_code = tickets.tickets_code;
        let refund_val = refund_val(tickets);

        let onedollar = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);

        let activity = reward_is_activity_token_internal(onedollar);

        //winner claim
        if(option::is_some(&onedollar.lucky_code)){
            let luckycode = option::borrow_with_default<u64>(&onedollar.lucky_code,&0);
            assert!(activity,error::unavailable(SALE_NOT_ACTIVITY));
            assert!(is_winner(luckycode,tickets),error::unauthenticated(ONLY_WINNER));
            let amount = onedollar.reward_val;
            token::direct_transfer(&resource_address_signer(),signer,onedollar.reward,amount);
            onedollar.is_claimed = true;
            change_state_internal(tickets,*luckycode,CLAIMED);
        }
        //refund claim
        else{
            //todo
            let refund = coin::extract<FundCoin>(&mut onedollar.fund,refund_val * onedollar.ticket_value);
            coin::deposit<FundCoin>(address_of(signer),refund);
            refund_state_internal(tickets);
            //tickets.refund = true;
            if(!onedollar.is_withdrawed){
                withdraw_token_internal(onedollar.reward,onedollar.reward_val);
            }
        };
    }

    public entry fun claim_and_refund<RewardCoin:key, FundCoin:key>(signer:&signer,onedollar_id:u64) acquires OneDollarsCoinCollection, OneDollarTicketsCollection{
        
        let collection = borrow_global_mut<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN);
        assert!(exists<OneDollarTicketsCollection>(address_of(signer)),error::not_found(TICKETS_NOT_FOUND));
        let tickets_collection = borrow_global_mut<OneDollarTicketsCollection>(address_of(signer));
        assert!(map::contains_key<u64,OneDollarTicket>(&tickets_collection.onedollar_tickets_map,&onedollar_id),error::not_found(TICKETS_NOT_FOUND));
        let tickets = map::borrow_mut<u64,OneDollarTicket>(&mut tickets_collection.onedollar_tickets_map,&onedollar_id);
        //let tickets_code = tickets.tickets_code;
        let refund_val = refund_val(tickets);

        let onedollar = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);

        let activity = reward_is_activity_internal(onedollar);

        //winner claim
        if(option::is_some(&onedollar.lucky_code)){
            let luckycode = option::borrow_with_default<u64>(&onedollar.lucky_code,&0);
            assert!(activity,error::unavailable(SALE_NOT_ACTIVITY));
            assert!(is_winner(luckycode,tickets),error::unauthenticated(ONLY_WINNER));

            let rewards = coin::extract_all<RewardCoin>(&mut onedollar.reward);
            coin::deposit<RewardCoin>(address_of(signer),rewards);
            onedollar.is_claimed = true;
            change_state_internal(tickets,*luckycode,CLAIMED);
            //tickets.claim = true;
        }
        //refund claim
        else{
            //todo
            let refund = coin::extract<FundCoin>(&mut onedollar.fund,refund_val * onedollar.ticket_value);
            coin::deposit<FundCoin>(address_of(signer),refund);
            refund_state_internal(tickets);
            //tickets.refund = true;
            if(!onedollar.is_withdrawed){
                withdraw_coin_internal<RewardCoin,FundCoin>(onedollar);
            }
        };

    }
    native public fun sip_hash(bytes: vector<u8>): u64;
    public fun sip_hash_from_value(v: u64): u64 {
        let bytes = bcs::to_bytes(&v);
        sip_hash(bytes)
        //1
    }
    public entry fun withdraw_token< FundCoin:key>(onedollar_id:u64)acquires OneDollarsTokenCollection , ResourceData{
        assert!(exists<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN), error::not_found(ONEDOLLARSMAP_NOT_FOUND));
        let collection = borrow_global_mut<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN);
        assert!(map::contains_key(&mut collection.onedollars_map,&onedollar_id),error::not_found(ONEDOLLAR_NOT_FOUND));
        let onedollar = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);
        assert!(!onedollar.is_withdrawed,error::unavailable(WITHDRAW_DENY));
        withdraw_token_internal(onedollar.reward,onedollar.reward_val);
    }

    fun withdraw_token_internal(tokenId:TokenId,amount:u64) acquires ResourceData {
        token::transfer(&resource_address_signer(),tokenId,ONEDOLLAR_ADMIN,amount);
    }

    public entry fun withdraw_coin<RewardCoin:key, FundCoin:key>(onedollar_id:u64)acquires OneDollarsCoinCollection{
        assert!(exists<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN), error::not_found(ONEDOLLARSMAP_NOT_FOUND));
        let collection = borrow_global_mut<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN);
        assert!(map::contains_key(&mut collection.onedollars_map,&onedollar_id),error::not_found(ONEDOLLAR_NOT_FOUND));
        let onedollar = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);
        assert!(!onedollar.is_withdrawed,error::unavailable(WITHDRAW_DENY));
        withdraw_coin_internal<RewardCoin,FundCoin>(onedollar);
    }

    fun withdraw_coin_internal<RewardCoin:key, FundCoin:key>(onedollar:&mut OneDollarCoin<RewardCoin,FundCoin>){
        let fund = coin::extract_all<RewardCoin>(&mut onedollar.reward);
        coin::deposit<RewardCoin>(ONEDOLLAR_ADMIN,fund);
        onedollar.is_withdrawed = true;
    }


    fun set_ticket_holder(onedollar_id:u64, ticket_id:u64,from:address,holder:address)acquires SelledAllTicketsTable{
        let table = table::borrow_mut( &mut borrow_global_mut<SelledAllTicketsTable>(ONEDOLLAR_ADMIN).selled_tickets,onedollar_id);
        if(map::contains_key(& table.selled_tickets,&ticket_id)){
            map::remove(&mut table.selled_tickets,&ticket_id);
        };
        map::add(&mut table.selled_tickets,ticket_id,holder);
        event::emit_event(&mut table.transfer_tickets_event , TransferTicketsEvent{ 
            from:from,
            to:holder,
            onedollar_id:onedollar_id,
            ticket_code:ticket_id,
            timestamp:timestamp::now_seconds()
        });

    }

    public entry fun change_state_coin<RewardCoin:key, FundCoin:key>(onedollar_id:u64,selling_time:u64) acquires OneDollarsCoinCollection{
        assert!(exists<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN), error::not_found(ONEDOLLARSMAP_NOT_FOUND));
        let collection = borrow_global_mut<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN);
        assert!(map::contains_key(&mut collection.onedollars_map,&onedollar_id),error::not_found(ONEDOLLAR_NOT_FOUND));
        let onedollar = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);
        onedollar.selling_time = selling_time;
    }

    public entry fun change_state_token<FundCoin:key>(onedollar_id:u64,selling_time:u64) acquires OneDollarsTokenCollection{
        assert!(exists<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN), error::not_found(ONEDOLLARSMAP_NOT_FOUND));
        let collection = borrow_global_mut<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN);
        assert!(map::contains_key(&mut collection.onedollars_map,&onedollar_id),error::not_found(ONEDOLLAR_NOT_FOUND));
        let onedollar = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);
        onedollar.selling_time = selling_time;
    }

    fun get_holder(onedollar_id:u64,ticket_id:u64):address acquires SelledAllTicketsTable{
        let map = table::borrow( &borrow_global_mut<SelledAllTicketsTable>(ONEDOLLAR_ADMIN).selled_tickets,onedollar_id);
        return *map::borrow( &map.selled_tickets,&ticket_id)
    }

    fun is_winner(luckycode:&u64,tickets:&OneDollarTicket):bool {
        contain_ticket(tickets,*luckycode)
    }


    fun tickets_info_internal<RewardCoin:key, FundCoin:key>(onedollar:&OneDollarCoin<RewardCoin,FundCoin>):(u64,u64){
        //total tickets and selled tickets
        (onedollar.total_tickets,onedollar.total_tickets-onedollar.selled_tickets)
    }

    fun tickets_info_token_internal<FundCoin:key>(onedollar:&OneDollarToken<FundCoin>):(u64,u64){
        //total tickets and selled tickets
        (onedollar.total_tickets,onedollar.total_tickets-onedollar.selled_tickets)
    }

    fun sale_is_open_token_internal<FundCoin:key>(onedollar:&OneDollarToken<FundCoin>):bool{
        onedollar.create_time+onedollar.delay_time <= timestamp::now_seconds()
    }

    fun sale_is_open_internal<RewardCoin:key, FundCoin:key>(onedollar:&OneDollarCoin<RewardCoin,FundCoin>):bool{
        onedollar.create_time+onedollar.delay_time <= timestamp::now_seconds()
    }

    fun sale_is_activity_token_internal<FundCoin:key>(onedollar:&OneDollarToken<FundCoin>):bool{
        onedollar.create_time+onedollar.delay_time+onedollar.selling_time>= timestamp::now_seconds()
    }


    fun sale_is_activity_internal<RewardCoin:key, FundCoin:key>(onedollar:&OneDollarCoin<RewardCoin,FundCoin>):bool{
        onedollar.create_time+onedollar.delay_time+onedollar.selling_time>= timestamp::now_seconds()
    }

    fun reward_is_activity_token_internal<FundCoin:key>(onedollar:&OneDollarToken<FundCoin>):bool{
        if(option::is_none(&onedollar.sell_out_time)){
            false
        }else{
            timestamp::now_seconds()>= option::get_with_default<u64>(&onedollar.sell_out_time,0)
        }
    }

    fun reward_is_activity_internal<RewardCoin:key, FundCoin:key>(onedollar:&OneDollarCoin<RewardCoin,FundCoin>):bool{
        if(option::is_none(&onedollar.sell_out_time)){
            false
        }else{
            timestamp::now_seconds()>= option::get_with_default<u64>(&onedollar.sell_out_time,0)
        }
    }

    fun is_creator(account:address):bool acquires Creator{
        //todo
        let creator = borrow_global_mut<Creator>(ONEDOLLAR_ADMIN);
        map::contains_key(&creator.address_map,&account)||account == ONEDOLLAR_ADMIN
    }

    public entry fun add_creator(signer:&signer,account:address) acquires Creator{
        assert!(address_of(signer)==ONEDOLLAR_ADMIN, error::unauthenticated(DOLLAR_ONLY_ADMIN));

        if(!exists<Creator>(ONEDOLLAR_ADMIN)){
            move_to(
                signer,
                Creator{
                    address_map:map::create<address,bool>()
                }
            );
        };
        let creator = borrow_global_mut<Creator>(ONEDOLLAR_ADMIN);
        map::add(&mut creator.address_map,account,true)
    }

    public entry fun delete_creator(signer:&signer,account:address) acquires Creator{
        assert!(address_of(signer)==ONEDOLLAR_ADMIN, error::unauthenticated(DOLLAR_ONLY_ADMIN));
        let creator = borrow_global_mut<Creator>(ONEDOLLAR_ADMIN);
        let (_,_) = map::remove(&mut creator.address_map,&account);
    }

    fun transfer_deny(onedollar_id:u64) acquires OneDollarStateList {
        let state_list = borrow_global_mut<OneDollarStateList>(ONEDOLLAR_ADMIN);
        let state = table::borrow(&state_list.state_table,onedollar_id);
        assert!(!(timestamp::now_seconds()>state.deadline || state.success == true),error::unauthenticated(55))
    }

    public entry fun change_name_coin<RewardCoin:key, FundCoin:key>(name:String,onedollar_id:u64) acquires OneDollarsCoinCollection{
        let collection = borrow_global_mut<OneDollarsCoinCollection<RewardCoin,FundCoin>>(ONEDOLLAR_ADMIN);
        let box = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);
        box.description = name;
    }

    public entry fun change_name_token<FundCoin:key>(name:String,onedollar_id:u64) acquires OneDollarsTokenCollection{
        let collection = borrow_global_mut<OneDollarsTokenCollection<FundCoin>>(ONEDOLLAR_ADMIN);
        let box = map::borrow_mut(&mut collection.onedollars_map,&onedollar_id);
        box.description = name;
    }

}