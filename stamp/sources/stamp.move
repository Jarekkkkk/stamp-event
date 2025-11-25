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
        points: u64,
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
        points: u64,
        event: String,
        description: String,
    }

    // === Events ===

    // === Method Aliases ===

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

        config.registered_collections.insert(collection_type, object::id(&stamp_display));
        transfer::public_transfer(stamp_display, ctx.sender());
    }

    public fun new_event(
        config: &mut Config,
        _cap: &AdminCap,
        name: String,
        description: String,
        image_url: String,
        points: u64,
    ) {
        config.assert_version();
        assert!(!config.events.contains(name), EDuplicateEventName);

        let event = Event {
            name,
            description,
            mint_count: 0,
            image_url,
            points,
        };

        config.events.add(name, event);
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

    public fun update_event_points(
        config: &mut Config,
        _cap: &AdminCap,
        name: String,
        points: u64,
    ) {
        config.assert_version();
        assert!(config.events.contains(name), EEventNotRegistered);

        (&mut config.events[name]).points = points;
    }

    // === Public Functions ===

    public fun mint<T>(config: &mut Config, event_name: String, ctx: &mut TxContext): Stamp<T> {
        config.assert_version();

        assert!(config.managers.contains(&ctx.sender()), ENotManager);
        assert!(config.events.contains(event_name), EEventNotRegistered);
        let event = &mut config.events[event_name];
        event.mint_count = event.mint_count + 1;

        let mut stamp_name = event.name;
        stamp_name.append(b"#".to_ascii_string());
        stamp_name.append(event.mint_count.to_string().to_ascii());

        Stamp {
            id: object::new(ctx),
            name: stamp_name,
            image_url: event.image_url,
            points: event.points,
            event: event_name,
            description: event.description,
        }
    }
    // === View Functions ===

    // === Package Functions ===

    // === Private Functions ===
    fun assert_version(config: &Config) {
        let v = PACKAGE_VERSION;
        assert!(config.versions.contains(&v), EInvalidPackageVersion);
    }
}
