#!/bin/bash

# Tailspin Space Game Local Runner (Bash version)
# Usage: ./run-local.sh [clean|stop|help]

set -e

# Configuration
NETWORK_NAME="spacegame-network"
WEB_CONTAINER="web"
LEADERBOARD_CONTAINER="leaderboard"
WEB_PORT=8080
LEADERBOARD_PORT=8081

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

show_help() {
    echo -e "${GREEN}Tailspin Space Game Local Runner${NC}"
    echo ""
    echo "Usage:"
    echo "  ./run-local.sh           - Build and run containers"
    echo "  ./run-local.sh clean     - Clean up and rebuild everything"
    echo "  ./run-local.sh stop      - Stop and remove containers"
    echo "  ./run-local.sh help      - Show this help"
    echo ""
    echo "Access URLs:"
    echo "  Web Application:  http://localhost:$WEB_PORT"
    echo "  Leaderboard API:  http://localhost:$LEADERBOARD_PORT/api/Leaderboard"
}

stop_containers() {
    echo -e "${YELLOW}Stopping and removing containers...${NC}"
    
    # Stop and remove containers if they exist
    for container in $WEB_CONTAINER $LEADERBOARD_CONTAINER; do
        if docker ps -a --format "{{.Names}}" | grep -q "^$container$"; then
            echo "  Removing container: $container"
            docker rm -f $container > /dev/null 2>&1 || true
        fi
    done
    
    # Remove network if it exists
    if docker network ls --format "{{.Name}}" | grep -q "^$NETWORK_NAME$"; then
        echo "  Removing network: $NETWORK_NAME"
        docker network rm $NETWORK_NAME > /dev/null 2>&1 || true
    fi
}

build_images() {
    echo -e "${GREEN}Building Docker images...${NC}"
    
    # Ensure we're in the repository root
    cd "$(dirname "$0")/.."
    
    echo "  Building web image..."
    if ! docker build -f Tailspin.SpaceGame.Web/Dockerfile -t web:latest . > /dev/null; then
        echo -e "${RED}Failed to build web image!${NC}"
        exit 1
    fi
    
    echo "  Building leaderboard image..."
    if ! docker build -f Tailspin.SpaceGame.LeaderboardContainer/Dockerfile -t leaderboard:latest . > /dev/null; then
        echo -e "${RED}Failed to build leaderboard image!${NC}"
        exit 1
    fi
    
    echo -e "  ${GREEN}Images built successfully!${NC}"
}

start_containers() {
    echo -e "${GREEN}Starting containers...${NC}"
    
    # Create network
    echo "  Creating network: $NETWORK_NAME"
    docker network create $NETWORK_NAME > /dev/null
    
    # Start leaderboard container
    echo "  Starting leaderboard container..."
    if ! docker run -d \
        --name $LEADERBOARD_CONTAINER \
        --network $NETWORK_NAME \
        -p $LEADERBOARD_PORT:80 \
        -e ASPNETCORE_URLS=http://0.0.0.0:80 \
        leaderboard:latest > /dev/null; then
        echo -e "${RED}Failed to start leaderboard container!${NC}"
        exit 1
    fi
    
    # Start web container
    echo "  Starting web container..."
    if ! docker run -d \
        --name $WEB_CONTAINER \
        --network $NETWORK_NAME \
        -p $WEB_PORT:80 \
        -e ASPNETCORE_URLS=http://0.0.0.0:80 \
        web:latest > /dev/null; then
        echo -e "${RED}Failed to start web container!${NC}"
        exit 1
    fi
    
    echo -e "  ${GREEN}Containers started successfully!${NC}"
}

test_services() {
    echo -e "${GREEN}Testing services...${NC}"
    
    # Wait a moment for services to start
    sleep 3
    
    # Test web application
    echo "  Testing web application..."
    if curl -s -f "http://localhost:$WEB_PORT" > /dev/null; then
        echo -e "    ${GREEN}✓ Web application is responding${NC}"
    else
        echo -e "    ${RED}✗ Web application is not responding${NC}"
    fi
    
    # Test leaderboard API
    echo "  Testing leaderboard API..."
    if curl -s -f "http://localhost:$LEADERBOARD_PORT/api/Leaderboard" > /dev/null; then
        echo -e "    ${GREEN}✓ Leaderboard API is responding${NC}"
    else
        echo -e "    ${RED}✗ Leaderboard API is not responding${NC}"
    fi
}

show_status() {
    echo ""
    echo -e "${CYAN}Container Status:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=$WEB_CONTAINER" --filter "name=$LEADERBOARD_CONTAINER"
    
    echo ""
    echo -e "${CYAN}Access URLs:${NC}"
    echo -e "  ${WHITE}Web Application:  http://localhost:$WEB_PORT${NC}"
    echo -e "  ${WHITE}Leaderboard API:  http://localhost:$LEADERBOARD_PORT/api/Leaderboard${NC}"
    echo ""
    echo -e "${CYAN}Management Commands:${NC}"
    echo -e "  ${WHITE}Stop containers:   ./run-local.sh stop${NC}"
    echo -e "  ${WHITE}View logs:         docker logs $WEB_CONTAINER${NC}"
    echo -e "  ${WHITE}                   docker logs $LEADERBOARD_CONTAINER${NC}"
}

# Main execution
case "${1:-}" in
    help)
        show_help
        exit 0
        ;;
    stop)
        stop_containers
        echo -e "${GREEN}Containers stopped and removed.${NC}"
        exit 0
        ;;
    clean)
        CLEAN=true
        ;;
esac

echo -e "${MAGENTA}🚀 Tailspin Space Game Local Runner${NC}"
echo -e "${MAGENTA}=====================================${NC}"

# Clean up if requested or if containers are already running
if [[ "${CLEAN:-false}" == "true" ]] || docker ps --format "{{.Names}}" | grep -qE "^($WEB_CONTAINER|$LEADERBOARD_CONTAINER)$"; then
    stop_containers
fi

# Build images
build_images

# Start containers
start_containers

# Test services
test_services

# Show status
show_status

echo ""
echo -e "${GREEN}🎉 Setup complete! Your applications are running locally.${NC}"