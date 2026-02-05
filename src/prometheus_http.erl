-module(prometheus_http).
-export([status_class/1]).

%% Stub implementation - returns status class for HTTP status codes
status_class(Status) when is_integer(Status), Status >= 100, Status < 200 -> "1xx";
status_class(Status) when is_integer(Status), Status >= 200, Status < 300 -> "2xx";
status_class(Status) when is_integer(Status), Status >= 300, Status < 400 -> "3xx";
status_class(Status) when is_integer(Status), Status >= 400, Status < 500 -> "4xx";
status_class(Status) when is_integer(Status), Status >= 500, Status < 600 -> "5xx";
status_class(_) -> "unknown".
