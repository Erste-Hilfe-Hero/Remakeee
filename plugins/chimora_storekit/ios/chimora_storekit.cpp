// GDExtension "ChimoraStoreKit" (iOS only): the engine singleton AppleBillingStore.gd talks to.
// Every method forwards to the StoreKit 2 code in ChimoraStoreKit.swift; answers come back as JSON
// through on_event and are emitted as the signal "billing_event" on the main thread.
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstdint>

extern "C" {
typedef void (*CKCallback)(const char *);
void ck_set_callback(CKCallback cb);
void ck_start(int64_t req);
void ck_query(const char *ids_json, int64_t req);
void ck_purchase(const char *product_id, const char *account_token, int64_t req);
void ck_finish(const char *txn, int64_t req);
void ck_owned(int64_t req);
void ck_restore(int64_t req);
}

using namespace godot;

class ChimoraStoreKit : public Object {
	GDCLASS(ChimoraStoreKit, Object);

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("start", "req"), &ChimoraStoreKit::start);
		ClassDB::bind_method(D_METHOD("query", "ids_json", "req"), &ChimoraStoreKit::query);
		ClassDB::bind_method(D_METHOD("purchase", "product_id", "account_token", "req"), &ChimoraStoreKit::purchase);
		ClassDB::bind_method(D_METHOD("finish", "txn", "req"), &ChimoraStoreKit::finish);
		ClassDB::bind_method(D_METHOD("owned", "req"), &ChimoraStoreKit::owned);
		ClassDB::bind_method(D_METHOD("restore", "req"), &ChimoraStoreKit::restore);
		ADD_SIGNAL(MethodInfo("billing_event", PropertyInfo(Variant::STRING, "json")));
	}

public:
	static ChimoraStoreKit *singleton;

	static void on_event(const char *json) {
		// Swift answers on the main actor; call_deferred keeps it safe either way.
		if (singleton) {
			singleton->call_deferred("emit_signal", "billing_event", String::utf8(json));
		}
	}

	void start(int64_t req) { ck_start(req); }
	void query(const String &ids_json, int64_t req) { ck_query(ids_json.utf8().get_data(), req); }
	void purchase(const String &product_id, const String &account_token, int64_t req) {
		ck_purchase(product_id.utf8().get_data(), account_token.utf8().get_data(), req);
	}
	void finish(const String &txn, int64_t req) { ck_finish(txn.utf8().get_data(), req); }
	void owned(int64_t req) { ck_owned(req); }
	void restore(int64_t req) { ck_restore(req); }
};

ChimoraStoreKit *ChimoraStoreKit::singleton = nullptr;

static void initialize(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(ChimoraStoreKit);
	ChimoraStoreKit::singleton = memnew(ChimoraStoreKit);
	Engine::get_singleton()->register_singleton("ChimoraStoreKit", ChimoraStoreKit::singleton);
	ck_set_callback(&ChimoraStoreKit::on_event);
}

static void uninitialize(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE || !ChimoraStoreKit::singleton) {
		return;
	}
	Engine::get_singleton()->unregister_singleton("ChimoraStoreKit");
	memdelete(ChimoraStoreKit::singleton);
	ChimoraStoreKit::singleton = nullptr;
}

extern "C" {
GDExtensionBool GDE_EXPORT chimora_storekit_init(GDExtensionInterfaceGetProcAddress get_proc_address,
		GDExtensionClassLibraryPtr library, GDExtensionInitialization *init) {
	GDExtensionBinding::InitObject init_obj(get_proc_address, library, init);
	init_obj.register_initializer(initialize);
	init_obj.register_terminator(uninitialize);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
