module stamp::stamp {
    use std::{ascii::String, type_name::{Self, TypeName}};
    use sui::{
        display,
        package::{Self, Publisher},
        table::{Self, Table},
        vec_map::{Self, VecMap},
        vec_set::{Self, VecSet}
    };

    // === Errors ===
    const EInvalidPackageVersion: u64 = 101;
    const EEventNotRegistered: u64 = 102;
    const EDuplicateEventName: u64 = 103;
    const EEventAlreadyExists: u64 = 104;
    const ECollectionAlreadyRegistered: u64 = 105;
    const ENotManager: u64 = 106;
    const ECollectionNotRegistered: u64 = 107;

    // === Constants ===

    const PACKAGE_VERSION: u64 = 1;

    // === Structs ===

    public struct STAMP has drop {}

    public struct AdminCap has key, store {
        id: UID,
    }

    public struct Event has store {
        name: String,
        description: String,
        mint_count: u32,
        image_url: String,
    }

    public struct Config has key, store {
        id: UID,
        versions: VecSet<u64>,
        managers: VecSet<address>,
        // collection imaage to url
        registered_collections: VecMap<TypeName, ID>,
        // event_name and corresponding metadata
        events: Table<String, Event>,
    }

    public struct Stamp<phantom Collection> has key {
        id: UID,
        name: String,
        image_url: String,
        event: String,
        description: String,
    }

    // === Events ===

    public struct NewCollection has copy, drop {
        collection_type: TypeName,
        display_id: ID,
        creator: address,
    }

    public struct NewEvent has copy, drop {
        name: String,
        description: String,
        image_url: String,
    }

    public struct MintEvent<phantom Collection> has copy, drop {
        stamp_id: ID,
        event_name: String,
        recipient: address,
        mint_count: u32,
    }

    // === Admin Functions ===

    fun init(otw: STAMP, ctx: &mut TxContext) {
        let sender = ctx.sender();

        // publisher
        let publisher = package::claim(otw, ctx);
        transfer::public_transfer(publisher, sender);

        // admin
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::public_transfer(admin_cap, sender);

        // config
        let config = Config {
            id: object::new(ctx),
            versions: vec_set::singleton(PACKAGE_VERSION),
            managers: vec_set::singleton(sender),
            registered_collections: vec_map::empty(),
            events: table::new(ctx),
        };
        transfer::public_share_object(config);
    }

    public fun add_version(config: &mut Config, _cap: &AdminCap, version: u64) {
        config.versions.insert(version);
    }

    public fun remove_version(config: &mut Config, _cap: &AdminCap, version: u64) {
        config.versions.remove(&version);
    }

    public fun add_manager(config: &mut Config, _cap: &AdminCap, manager: address) {
        config.managers.insert(manager);
    }

    public fun remove_manager(config: &mut Config, _cap: &AdminCap, manager: address) {
        config.managers.remove(&manager);
    }

    #[allow(lint(self_transfer))]
    public fun new_collection<Collection: drop>(
        config: &mut Config,
        publisher: &mut Publisher,
        ctx: &mut TxContext,
    ) {
        config.assert_version();

        let collection_type = type_name::with_defining_ids<Collection>();
        assert!(
            !config.registered_collections.contains(&collection_type),
            ECollectionAlreadyRegistered,
        );

        // create display
        let keys = vector[
            b"name".to_string(),
            b"image_url".to_string(),
            b"event".to_string(),
            b"description".to_string(),
        ];

        let values = vector[
            b"{name}".to_string(),
            b"{image_url}".to_string(),
            b"{event}".to_string(),
            b"{description}".to_string(),
        ];

        let mut stamp_display = display::new_with_fields<Stamp<Collection>>(
            publisher,
            keys,
            values,
            ctx,
        );
        stamp_display.update_version();

        let display_id = object::id(&stamp_display);
        config.registered_collections.insert(collection_type, display_id);

        // Emit new collection event
        sui::event::emit(NewCollection {
            collection_type,
            display_id,
            creator: ctx.sender(),
        });

        transfer::public_transfer(stamp_display, ctx.sender());
    }

    public fun new_event(
        config: &mut Config,
        _cap: &AdminCap,
        name: String,
        description: String,
        image_url: String,
    ) {
        config.assert_version();

        assert!(!config.events.contains(name), EDuplicateEventName);

        let event = Event {
            name,
            description,
            mint_count: 0,
            image_url,
        };

        config.events.add(name, event);

        // Emit new event
        sui::event::emit(NewEvent {
            name,
            description,
            image_url,
        });
    }

    public fun update_event_name(
        config: &mut Config,
        prev_event_name: String,
        new_event: String,
        _cap: &AdminCap,
    ) {
        config.assert_version();
        assert!(config.events.contains(prev_event_name), EEventNotRegistered);
        assert!(!config.events.contains(new_event), EEventAlreadyExists);

        let event = config.events.remove(prev_event_name);

        config.events.add(new_event, event);
    }

    public fun update_event_description(
        config: &mut Config,
        _cap: &AdminCap,
        name: String,
        description: String,
    ) {
        config.assert_version();
        assert!(config.events.contains(name), EEventNotRegistered);

        (&mut config.events[name]).description = description;
    }

    public fun update_event_image_url(
        config: &mut Config,
        _cap: &AdminCap,
        name: String,
        image_url: String,
    ) {
        config.assert_version();
        assert!(config.events.contains(name), EEventNotRegistered);

        (&mut config.events[name]).image_url = image_url;
    }

    // === Public Functions ===

    public fun mint_to<Collection: drop>(
        config: &mut Config,
        event_name: String,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        config.assert_version();

        assert!(config.managers.contains(&ctx.sender()), ENotManager);
        assert!(config.events.contains(event_name), EEventNotRegistered);
        assert!(
            config.registered_collections.contains(&type_name::with_defining_ids<Collection>()),
            ECollectionNotRegistered,
        );

        let event = &mut config.events[event_name];
        event.mint_count = event.mint_count + 1;

        let mut stamp_name = event.name;
        stamp_name.append(b"#".to_ascii_string());
        stamp_name.append(event.mint_count.to_string().to_ascii());

        let stamp = Stamp<Collection> {
            id: object::new(ctx),
            name: stamp_name,
            image_url: event.image_url,
            event: event_name,
            description: event.description,
        };

        // Emit mint event
        sui::event::emit(MintEvent<Collection> {
            stamp_id: object::id(&stamp),
            event_name,
            recipient,
            mint_count: event.mint_count,
        });

        transfer::transfer(stamp, recipient);
    }

    // === View Functions ===

    // Config view functions
    public fun get_supported_versions(config: &Config): vector<u64> {
        config.versions.into_keys()
    }

    public fun get_managers(config: &Config): vector<address> {
        config.managers.into_keys()
    }

    public fun is_manager(config: &Config, addr: address): bool {
        config.managers.contains(&addr)
    }

    public fun get_registered_collections(config: &Config): vector<TypeName> {
        let (keys, _) = config.registered_collections.into_keys_values();
        keys
    }

    public fun get_collection_display_id(config: &Config, collection_type: TypeName): Option<ID> {
        if (config.registered_collections.contains(&collection_type)) {
            option::some(config.registered_collections[&collection_type])
        } else {
            option::none()
        }
    }

    public fun is_collection_registered(config: &Config, collection_type: TypeName): bool {
        config.registered_collections.contains(&collection_type)
    }

    public fun event_exists(config: &Config, event_name: String): bool {
        config.events.contains(event_name)
    }

    // Event view functions
    public fun get_event_name(config: &Config, event_name: String): Option<String> {
        if (config.events.contains(event_name)) {
            option::some(config.events[event_name].name)
        } else {
            option::none()
        }
    }

    public fun get_event_description(config: &Config, event_name: String): Option<String> {
        if (config.events.contains(event_name)) {
            option::some(config.events[event_name].description)
        } else {
            option::none()
        }
    }

    public fun get_event_mint_count(config: &Config, event_name: String): Option<u32> {
        if (config.events.contains(event_name)) {
            option::some(config.events[event_name].mint_count)
        } else {
            option::none()
        }
    }

    public fun get_event_image_url(config: &Config, event_name: String): Option<String> {
        if (config.events.contains(event_name)) {
            option::some(config.events[event_name].image_url)
        } else {
            option::none()
        }
    }

    // Stamp view functions
    public fun get_stamp_name<T>(stamp: &Stamp<T>): String {
        stamp.name
    }

    public fun get_stamp_image_url<T>(stamp: &Stamp<T>): String {
        stamp.image_url
    }

    public fun get_stamp_event<T>(stamp: &Stamp<T>): String {
        stamp.event
    }

    public fun get_stamp_description<T>(stamp: &Stamp<T>): String {
        stamp.description
    }

    public fun get_stamp_info<T>(stamp: &Stamp<T>): (String, String, String, String) {
        (stamp.name, stamp.image_url, stamp.event, stamp.description)
    }

    // === Private Functions ===
    fun assert_version(config: &Config) {
        let v = PACKAGE_VERSION;
        assert!(config.versions.contains(&v), EInvalidPackageVersion);
    }

    // === Test Functions ===
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(STAMP {}, ctx);
    }
}
