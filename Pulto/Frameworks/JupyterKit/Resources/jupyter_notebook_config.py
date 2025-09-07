c = get_config()  # type: ignore
c.ServerApp.port_retries = 0
c.ServerApp.ip = "127.0.0.1"
c.ServerApp.open_browser = False
c.ServerApp.allow_remote_access = False
c.ServerApp.allow_origin = ""
c.ServerApp.token = ""
c.ServerApp.password = ""
