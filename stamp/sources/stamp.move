module stamp::stamp {
    use std::{ascii::String, type_name::TypeName};
    use sui::{
        display,
        package::{Self, Publisher},
        table::{Self, Table},
        vec_set::{Self, VecSet}
    };

    // === Errors ===
    const EInvalidPackageVersion: u64 = 101;
    const EEventNotRegistered: u64 = 102;

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
        count: u32,
        image_url: String,
        points: u64,
    }

    public struct Config has key, store {
        id: UID,
        versions: VecSet<u64>,
        managers: VecSet<address>,
        // collection imaage to url
        registered_collections: VecSet<TypeName>,
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
            registered_collections: vec_set::empty(),
            events: table::new(ctx),
        };
        transfer::public_share_object(config);
    }

    #[allow(lint(self_transfer))]
    public fun new_event<Event: drop>(publisher: &mut Publisher, ctx: &mut TxContext) {
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

        let mut stamp_display = display::new_with_fields<Stamp<Event>>(
            publisher,
            keys,
            values,
            ctx,
        );

        stamp_display.update_version();
        transfer::public_transfer(stamp_display, ctx.sender());
    }

    // === Public Functions ===

    public fun mint<T>(
        config: &mut Config,
        _cap: &AdminCap,
        event_name: String,
        ctx: &mut TxContext,
    ): Stamp<T> {
        config.assert_version();

        assert!(config.events.contains(event_name), EEventNotRegistered);
        let event = &mut config.events[event_name];
        event.count = event.count + 1;

        let mut stamp_name = event.name;
        stamp_name.append(b"#".to_ascii_string());
        stamp_name.append(event.count.to_string().to_ascii());

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

    // === Admin Functions ===

    // === Package Functions ===

    // === Private Functions ===
    fun assert_version(config: &Config) {
        let v = PACKAGE_VERSION;
        assert!(config.versions.contains(&v), EInvalidPackageVersion);
    }

    // === Test Functions ===
}
