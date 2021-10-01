package plugin

import (
	"git.sr.ht/~akilan1999/p2p-rendering-computation/config"
	"github.com/go-git/go-git/v5"
	"os"
	"net/url"
	"strings"
)

// DownloadPlugin This functions downloads package from
// a git repo
func DownloadPlugin(pluginurl string) error {
	// paring plugin url
	u, err := url.Parse(pluginurl)
	if err != nil {
		return err
	}
	path := u.Path
	// Trim first character of the string
	path = path[1:]
	// trim last element of the string
	path = path[:len(path)-1]
	// Replaces / with _
	folder := strings.Replace(path, "/", "_", -1)
	// Reads plugin path from the config path
	config, err := config.ConfigInit()
	if err != nil {
		return err
	}
	// clones a repo and stores it at the plugin directory
	_, err = git.PlainClone(config.PluginPath + "/" + folder, false, &git.CloneOptions{
		URL:      pluginurl,
		Progress: os.Stdout,
	})
	// returns error if raised
	if err != nil {
		return err
	}


	return nil
}