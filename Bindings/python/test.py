from library import *


if __name__ == "__main__":
    P2PRCNodes = ListNodes()
    # Print nodes in the network
    print(P2PRCNodes)

    # Add custom information to the network
    if AddCustomInformation("Test"):
        print("It worked")

    if AddRootNode("0.0.0.0", "8081"):
        print("It worked for adding root node")
