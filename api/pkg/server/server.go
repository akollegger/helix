package server

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/lukemarsden/helix/api/pkg/controller"
	"github.com/lukemarsden/helix/api/pkg/store"
	"github.com/lukemarsden/helix/api/pkg/system"
)

const API_PREFIX = "/api/v1"

type ServerOptions struct {
	URL           string
	Host          string
	Port          int
	KeyCloakURL   string
	KeyCloakToken string
	// this is for when we are running localfs filesystem
	// and we need to add a route to view files based on their path
	// we are assuming all file storage is open right now
	// so we just deep link to the object path and don't apply auth
	// (this is so helix nodes can see files)
	// later, we might add a token to the URLs
	LocalFilestorePath string
}

type HelixAPIServer struct {
	Options    ServerOptions
	Store      store.Store
	Controller *controller.Controller
}

func NewServer(
	options ServerOptions,
	store store.Store,
	controller *controller.Controller,
) (*HelixAPIServer, error) {
	if options.URL == "" {
		return nil, fmt.Errorf("server url is required")
	}
	if options.Host == "" {
		return nil, fmt.Errorf("server host is required")
	}
	if options.Port == 0 {
		return nil, fmt.Errorf("server port is required")
	}
	if options.KeyCloakURL == "" {
		return nil, fmt.Errorf("keycloak url is required")
	}
	if options.KeyCloakToken == "" {
		return nil, fmt.Errorf("keycloak token is required")
	}

	return &HelixAPIServer{
		Options:    options,
		Store:      store,
		Controller: controller,
	}, nil
}

func (apiServer *HelixAPIServer) ListenAndServe(ctx context.Context, cm *system.CleanupManager) error {
	router := mux.NewRouter()
	router.Use(apiServer.corsMiddleware)

	subrouter := router.PathPrefix(API_PREFIX).Subrouter()

	// add one more subrouter for the authenticated service methods
	authRouter := subrouter.MatcherFunc(func(r *http.Request, rm *mux.RouteMatch) bool {
		return true
	}).Subrouter()

	keycloak := newKeycloak(apiServer.Options)
	keyCloakMiddleware := newMiddleware(keycloak, apiServer.Options, apiServer.Store)
	authRouter.Use(keyCloakMiddleware.verifyToken)

	subrouter.HandleFunc("/config", WrapperWithConfig(apiServer.config, WrapperConfig{
		SilenceErrors: true,
	})).Methods("GET")

	authRouter.HandleFunc("/status", Wrapper(apiServer.status)).Methods("GET")
	authRouter.HandleFunc("/transactions", Wrapper(apiServer.getTransactions)).Methods("GET")

	authRouter.HandleFunc("/filestore/config", Wrapper(apiServer.filestoreConfig)).Methods("GET")
	authRouter.HandleFunc("/filestore/list", Wrapper(apiServer.filestoreList)).Methods("GET")
	authRouter.HandleFunc("/filestore/get", Wrapper(apiServer.filestoreGet)).Methods("GET")
	authRouter.HandleFunc("/filestore/folder", Wrapper(apiServer.filestoreCreateFolder)).Methods("POST")
	authRouter.HandleFunc("/filestore/upload", Wrapper(apiServer.filestoreUpload)).Methods("POST")
	authRouter.HandleFunc("/filestore/rename", Wrapper(apiServer.filestoreRename)).Methods("PUT")
	authRouter.HandleFunc("/filestore/delete", Wrapper(apiServer.filestoreDelete)).Methods("DELETE")

	authRouter.HandleFunc("/api_keys", Wrapper(apiServer.createAPIKey)).Methods("POST")
	authRouter.HandleFunc("/api_keys", Wrapper(apiServer.getAPIKeys)).Methods("GET")
	authRouter.HandleFunc("/api_keys", Wrapper(apiServer.deleteAPIKey)).Methods("DELETE")
	authRouter.HandleFunc("/api_keys/check", Wrapper(apiServer.checkAPIKey)).Methods("GET")

	if apiServer.Options.LocalFilestorePath != "" {
		fileServer := http.FileServer(http.Dir(apiServer.Options.LocalFilestorePath))
		subrouter.PathPrefix("/filestore/viewer/").Handler(http.StripPrefix(fmt.Sprintf("%s/filestore/viewer/", API_PREFIX), http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			fileServer.ServeHTTP(w, r)
		})))
	}

	authRouter.HandleFunc("/sessions", Wrapper(apiServer.getSessions)).Methods("GET")
	authRouter.HandleFunc("/sessions", Wrapper(apiServer.createSession)).Methods("POST")
	authRouter.HandleFunc("/sessions/{id}", Wrapper(apiServer.getSession)).Methods("GET")
	authRouter.HandleFunc("/sessions/{id}", Wrapper(apiServer.updateSession)).Methods("PUT")
	authRouter.HandleFunc("/sessions/{id}", Wrapper(apiServer.deleteSession)).Methods("DELETE")

	// TODO: this has no auth right now
	// we need to add JWTs to the urls we are using to connect models to the workers
	// the task filters (mode, type and modelName) are all given as query params
	subrouter.HandleFunc("/runner/{runnerid}/nextsession", WrapperWithConfig(apiServer.getNextRunnerSession, WrapperConfig{
		SilenceErrors: true,
	})).Methods("GET")

	subrouter.HandleFunc("/runner/{runnerid}/response", Wrapper(apiServer.respondRunnerSession)).Methods("POST")

	// handle downloading a single file from a session to a runner
	subrouter.HandleFunc("/runner/{runnerid}/session/{sessionid}/download", apiServer.runnerSessionDownloadFile).Methods("GET")

	// all files uploaded will be put under the "sessions/{sessionid}/results" folder in the filestore
	subrouter.HandleFunc("/runner/{runnerid}/session/{sessionid}/upload", Wrapper(apiServer.runnerSessionUploadFiles)).Methods("POST")

	StartWebSocketServer(
		ctx,
		subrouter,
		"/ws",
		apiServer.Controller.SessionUpdatesChan,
		keyCloakMiddleware.userIDFromRequest,
	)

	srv := &http.Server{
		Addr:              fmt.Sprintf("%s:%d", apiServer.Options.Host, apiServer.Options.Port),
		WriteTimeout:      time.Minute * 15,
		ReadTimeout:       time.Minute * 15,
		ReadHeaderTimeout: time.Minute * 15,
		IdleTimeout:       time.Minute * 60,
		Handler:           router,
	}
	return srv.ListenAndServe()
}
