using System;
using System.Net.NetworkInformation;

namespace EloteWindows.Services
{
    public static class NetworkService
    {
        /// <summary>
        /// Checks if network connectivity is available
        /// </summary>
        /// <returns>True if network is available, false otherwise</returns>
        public static bool IsNetworkAvailable()
        {
            try
            {
                return NetworkInterface.GetIsNetworkAvailable();
            }
            catch (Exception)
            {
                return false;
            }
        }
    }
}
