using System;
using System.Text;
using Godot;
using Godot.Collections;
using TcpServerPeer = Godot.TcpServer;

namespace LaunchMonitors.Common.Tcp;

public partial class TcpServer : Node
{
    private const int MaxTcpBuffer = 65536;
    private const int DefaultPort = 49152;

    private readonly TcpServerPeer _tcpServer = new();
    private StreamPeerTcp? _tcpConnection;
    private bool _tcpConnected;
    private string _tcpString = string.Empty;
    private string _connectedHost = string.Empty;
    private Dictionary _shotData = new();
    private readonly Dictionary _resp200 = new() { { "Code", 200 } };
    private readonly Dictionary _resp50x = new() { { "Code", 501 }, { "Message", "Failure Occured" } };

    [Signal]
    public delegate void HitBallEventHandler(Dictionary data);

    [Signal]
    public delegate void StatusChangedEventHandler(string status);

    [Export]
    public int Port { get; set; } = DefaultPort;

    public bool IsListening => _tcpServer.IsListening();

    public bool HasConnection => _tcpConnected;

    public string ConnectedHost => _connectedHost;

    public void StartListening(int port)
    {
        ListenOnPort(port);
    }

    public override void _ExitTree()
    {
        Shutdown();
    }

    public override void _Process(double delta)
    {
        if (!_tcpConnected)
        {
            _tcpConnection = _tcpServer.TakeConnection();
            if (_tcpConnection != null)
            {
                _connectedHost = _tcpConnection.GetConnectedHost() ?? string.Empty;
                GD.Print($"We have a tcp connection at {_connectedHost}");
                _tcpConnected = true;
                var hostLabel = string.IsNullOrEmpty(_connectedHost) ? "unknown" : _connectedHost;
                EmitStatus($"Connected: {hostLabel}");
            }

            return;
        }

        if (_tcpConnection == null)
        {
            _tcpConnected = false;
            _connectedHost = string.Empty;
            return;
        }

        _tcpConnection.Poll();
        var status = _tcpConnection.GetStatus();
        if (status == StreamPeerTcp.Status.None)
        {
            _tcpConnected = false;
            _connectedHost = string.Empty;
            GD.Print("tcp disconnected");
            EmitListeningStatus();
            return;
        }

        if (status != StreamPeerTcp.Status.Connected)
        {
            return;
        }

        var bytesAvailable = (int)_tcpConnection.GetAvailableBytes();
        if (bytesAvailable <= 0)
        {
            return;
        }

        if (bytesAvailable > MaxTcpBuffer)
        {
            GD.PushWarning($"TCP payload too large ({bytesAvailable} bytes), dropping");
            _ = _tcpConnection.GetUtf8String(bytesAvailable);
            respond_error(413, "Payload too large");
            return;
        }

        _tcpString = _tcpConnection.GetUtf8String(bytesAvailable);
        var json = new Json();
        if (json.Parse(_tcpString) != Error.Ok)
        {
            respond_error(501, "Bad JSON data");
            return;
        }

        var data = json.GetData();
        if (data.VariantType != Variant.Type.Dictionary)
        {
            respond_error(501, "Expected JSON object");
            return;
        }

        _shotData = data.AsGodotDictionary();
        GD.Print($"Launch monitor payload: {_tcpString}");

        if (_shotData.TryGetValue("ShotDataOptions", out var shotDataOptionsVar)
            && shotDataOptionsVar.VariantType == Variant.Type.Dictionary)
        {
            var shotDataOptions = shotDataOptionsVar.AsGodotDictionary();
            if (shotDataOptions.TryGetValue("ContainsBallData", out var containsBallDataVar)
                && containsBallDataVar.VariantType == Variant.Type.Bool
                && (bool)containsBallDataVar
                && _shotData.TryGetValue("BallData", out var ballDataVar)
                && ballDataVar.VariantType == Variant.Type.Dictionary)
            {
                EmitSignal(SignalName.HitBall, ballDataVar.AsGodotDictionary());
                return;
            }
        }

        respond_error(501, "Missing or invalid shot data");
    }

    public void respond_error(int code, string message)
    {
        if (_tcpConnection == null)
        {
            return;
        }

        _tcpConnection.Poll();
        var status = _tcpConnection.GetStatus();
        if (status == StreamPeerTcp.Status.None)
        {
            _tcpConnected = false;
            return;
        }

        if (status != StreamPeerTcp.Status.Connected)
        {
            return;
        }

        _resp50x["Code"] = code;
        _resp50x["Message"] = message;
        _tcpConnection.PutData(Encoding.ASCII.GetBytes(Json.Stringify(_resp50x)));
    }

    public void _on_golf_ball_good_data()
    {
        if (_tcpConnection == null)
        {
            return;
        }

        _tcpConnection.Poll();
        var status = _tcpConnection.GetStatus();
        if (status == StreamPeerTcp.Status.None)
        {
            _tcpConnected = false;
            return;
        }

        if (status == StreamPeerTcp.Status.Connected)
        {
            _tcpConnection.PutData(Encoding.ASCII.GetBytes(Json.Stringify(_resp200)));
        }
    }

    public void _on_player_bad_data()
    {
        respond_error(501, "Invalid ball data");
    }

    public void StopListening()
    {
        Shutdown();
        EmitStatus("Stopped");
    }

    public bool GetIsListening()
    {
        return IsListening;
    }

    public bool GetIsConnected()
    {
        return HasConnection;
    }

    public string GetConnectedHost()
    {
        return ConnectedHost;
    }

    private void ListenOnPort(int port)
    {
        Port = Math.Clamp(port, 1, 65535);
        Shutdown();

        var error = _tcpServer.Listen((ushort)Port);
        if (error != Error.Ok)
        {
            GD.PushError($"TCP server failed to listen on port {Port}. Error: {error}");
            EmitStatus($"Failed: {error}");
            return;
        }

        EmitListeningStatus();
    }

    private void Shutdown()
    {
        if (_tcpConnection != null)
        {
            _tcpConnection.DisconnectFromHost();
            _tcpConnection = null;
        }

        _tcpConnected = false;
        _connectedHost = string.Empty;
        _shotData.Clear();
        _tcpString = string.Empty;

        if (_tcpServer.IsListening())
        {
            _tcpServer.Stop();
        }
    }

    private void EmitListeningStatus()
    {
        EmitStatus(_tcpServer.IsListening() ? $"Listening on {Port}" : "Stopped");
    }

    private void EmitStatus(string status)
    {
        EmitSignal(SignalName.StatusChanged, status);
    }
}
