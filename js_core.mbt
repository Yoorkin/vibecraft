///|
#external
priv type JsValue

///|
extern "js" fn js_error(msg : String) -> Unit =
  #| (msg) => console.error(msg)
