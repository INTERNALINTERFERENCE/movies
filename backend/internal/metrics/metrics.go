package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
)

var ActiveConnections = prometheus.NewGauge(
	prometheus.GaugeOpts{
		Name: "ws_active_connections",
		Help: "Current number of active websocket connections.",
	},
)

func init() {
	prometheus.MustRegister(ActiveConnections)
}
